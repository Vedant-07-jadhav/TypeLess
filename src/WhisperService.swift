import Foundation

class WhisperService {
    static let shared = WhisperService()

    func transcribeAndPolish(audioURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        let config = AppConfig.shared
        let apiKey = config.apiKey
        let provider = config.provider
        let mode = config.mode

        guard !apiKey.isEmpty else {
            completion(.failure(NSError(domain: "TypeLess", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "API Key is missing. Please set your \(provider.rawValue.capitalized) API Key in TypeLess Settings."
            ])))
            return
        }

        transcribeAudio(fileURL: audioURL, provider: provider, apiKey: apiKey) { result in
            switch result {
            case .failure(let err):
                completion(.failure(err))
            case .success(let rawTranscript):
                let cleaned = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.isEmpty {
                    completion(.failure(NSError(domain: "TypeLess", code: 204, userInfo: [
                        NSLocalizedDescriptionKey: "No speech detected in audio."
                    ])))
                    return
                }

                // If mode is raw, we are done!
                if mode == .raw {
                    completion(.success(cleaned))
                    return
                }

                // Otherwise, perform LLM post-processing
                self.polishText(rawText: cleaned, mode: mode, provider: provider, apiKey: apiKey) { polishResult in
                    switch polishResult {
                    case .success(let polished):
                        completion(.success(polished))
                    case .failure:
                        // Fallback to raw transcript so user never loses their dictated text
                        completion(.success(cleaned))
                    }
                }
            }
        }
    }

    private func transcribeAudio(fileURL: URL, provider: APIProvider, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        var request = URLRequest(url: provider.whisperURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        do {
            let fileData = try Data(contentsOf: fileURL)
            let body = buildMultipartFormData(boundary: boundary, fileData: fileData, filename: fileURL.lastPathComponent, model: provider.whisperModel)
            request.httpBody = body
        } catch {
            completion(.failure(error))
            return
        }

        let session = URLSession(configuration: .ephemeral)
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "TypeLess", code: 500, userInfo: [
                    NSLocalizedDescriptionKey: "Empty response from speech recognition server."
                ])))
                return
            }

            // Check HTTP status code
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errObj = json["error"] as? [String: Any],
                   let msg = errObj["message"] as? String {
                    completion(.failure(NSError(domain: "TypeLess", code: http.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "\(provider.rawValue.capitalized) Error: \(msg)"
                    ])))
                    return
                }
                let bodyStr = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                completion(.failure(NSError(domain: "TypeLess", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Server returned error (\(http.statusCode)): \(bodyStr)"
                ])))
                return
            }

            // Parse Whisper output
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let text = json["text"] as? String {
                    completion(.success(text))
                } else {
                    completion(.failure(NSError(domain: "TypeLess", code: 500, userInfo: [
                        NSLocalizedDescriptionKey: "Unable to parse transcript from response."
                    ])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func polishText(rawText: String, mode: DictationMode, provider: APIProvider, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        let systemPrompt: String
        switch mode {
        case .smart:
            systemPrompt = """
You are TypeLess, an intelligent speech-to-text post-processor.
Your task:
1. Clean up spoken disfluencies: eliminate filler words ("um", "uh", "you know", "like", "sort of", "ah", "er").
2. Fix stuttering, false starts, and accidental word repetitions.
3. Apply accurate punctuation, capitalization, numbers, and dates.
4. Keep the exact voice, style, vocabulary, and meaning of the speaker.
5. Return ONLY the polished final text. Do NOT add conversational replies, quotes, or preambles.
"""
        case .bullet:
            systemPrompt = """
You are an executive assistant. Convert the user's spoken thoughts into clear, concise bullet points or action items.
Format:
- Bullet points using standard hyphens.
- Keep phrasing concise, actionable, and structured.
- Return ONLY the bullet points, without introductory or closing chit-chat.
"""
        case .email:
            systemPrompt = """
You are a professional writing assistant. Convert the user's spoken stream of thoughts into a polite, structured email draft.
Format:
Subject: <Clear Subject Line>

Hi <Name or Team>,

<Email body paragraphs>

Best regards,
<Speaker>
Return ONLY the formatted email text with no extra conversational commentary.
"""
        case .raw:
            completion(.success(rawText))
            return
        }

        var request = URLRequest(url: provider.chatURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": provider.chatModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": rawText]
            ],
            "temperature": 0.2
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(.success(rawText))
            return
        }
        request.httpBody = httpBody

        let session = URLSession(configuration: .ephemeral)
        session.dataTask(with: request) { data, response, error in
            guard error == nil, let data = data else {
                completion(.success(rawText))
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                let polished = content.trimmingCharacters(in: .whitespacesAndNewlines)
                completion(.success(polished.isEmpty ? rawText : polished))
            } else {
                completion(.success(rawText))
            }
        }.resume()
    }

    func testConnection(provider: APIProvider, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard !apiKey.isEmpty else {
            completion(.failure(NSError(domain: "TypeLess", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "API Key cannot be blank."
            ])))
            return
        }

        let modelsURL: URL
        switch provider {
        case .groq:
            modelsURL = URL(string: "https://api.groq.com/openai/v1/models")!
        case .openai:
            modelsURL = URL(string: "https://api.openai.com/v1/models")!
        }

        var request = URLRequest(url: modelsURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .ephemeral)
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "TypeLess", code: 500, userInfo: [
                    NSLocalizedDescriptionKey: "No data received from \(provider.rawValue.capitalized)."
                ])))
                return
            }

            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errObj = json["error"] as? [String: Any],
                   let msg = errObj["message"] as? String {
                    completion(.failure(NSError(domain: "TypeLess", code: http.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "\(provider.rawValue.capitalized) Error: \(msg)"
                    ])))
                    return
                }
                completion(.failure(NSError(domain: "TypeLess", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "HTTP error: \(http.statusCode)"
                ])))
                return
            }

            completion(.success("API Key is valid and connected to \(provider.displayName)!"))
        }.resume()
    }

    private func buildMultipartFormData(boundary: String, fileData: Data, filename: String, model: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        // Model field
        body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        body.append("\(model)\(lineBreak)".data(using: .utf8)!)

        // Response format
        body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        body.append("json\(lineBreak)".data(using: .utf8)!)

        // Audio File field
        body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        body.append(fileData)
        body.append("\(lineBreak)".data(using: .utf8)!)

        // Closing boundary
        body.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        return body
    }
}
