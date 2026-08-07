import Foundation
import OpenAI
import SwiftAnthropic

/// LLM 调用相关的错误，带本地化说明，直接 show 给用户。
enum LLMError: LocalizedError {
    case missingKey
    case badURL
    case http(status: Int, body: String)
    case noContent
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return L10n.t("缺少 API Key", "API key is missing")
        case .badURL:
            return L10n.t("模型地址不合法", "The model endpoint URL is invalid")
        case .http(let status, _):
            return L10n.t("模型返回错误（HTTP \(status)）", "The model returned an error (HTTP \(status))")
        case .noContent:
            return L10n.t("模型没有返回内容", "The model returned no content")
        case .underlying(let e):
            return e.localizedDescription
        }
    }
}

/// 极简 LLM 客户端：只做一件事——把 `AIModelConfig` + 对话历史发给真实模型，返回纯文本。
///
/// 协议兼容交给成熟的开源 SDK，不再手写 JSON / 请求头 / 响应解析：
/// - **OpenAI 兼容**（`customOpenAI`）：[MacPaw/OpenAI](https://github.com/MacPaw/OpenAI)
///   —— `POST {base}/chat/completions`，`Authorization: Bearer <key>`。
/// - **Anthropic 兼容**（`customAnthropic`）：[SwiftAnthropic](https://github.com/jamesrochabrun/SwiftAnthropic)
///   —— `POST {base}/v1/messages`，`x-api-key` + `anthropic-version` 头，`system` 走顶级字段。
///
/// 对外签名（`complete(config:messages:system:)`）保持不变，所以 Agent 运行时与 CLI 入口
/// 一行都不用改——只是底层协议处理从手写 JSON 换成了上述 SDK。
struct LLMClient {

    /// 调一次模型。
    /// - Parameters:
    ///   - messages: 对话历史，role 只取 `"user"` / `"assistant"`，不含 system（system 单独传）。
    ///   - system: 系统提示词。
    static func complete(config: AIModelConfig,
                          messages: [(role: String, content: String)],
                          system: String) async throws -> String {
        guard !config.apiKey.isEmpty else { throw LLMError.missingKey }

        if config.provider.isAnthropicProtocol {
            return try await completeAnthropic(config: config, messages: messages, system: system)
        } else {
            return try await completeOpenAI(config: config, messages: messages, system: system)
        }
    }

    // MARK: - OpenAI 兼容（MacPaw/OpenAI）

    private static func completeOpenAI(config: AIModelConfig,
                                        messages: [(role: String, content: String)],
                                        system: String) async throws -> String {
        let (scheme, host, basePath) = splitBaseURL(config.effectiveBaseURL)
        let openAI = OpenAI(configuration: OpenAI.Configuration(
            token: config.apiKey,
            host: host,
            scheme: scheme,
            basePath: basePath
        ))

        let apiMessages: [ChatQuery.ChatCompletionMessageParam] = [
            .system(.init(content: .textContent(system)))
        ] + messages.map { m in
            if m.role == "assistant" {
                return .assistant(.init(content: .textContent(m.content)))
            }
            return .user(.init(content: .string(m.content)))
        }

        let query = ChatQuery(
            messages: apiMessages,
            model: config.effectiveModel,
            maxCompletionTokens: 2048,
            temperature: 0.3
        )

        do {
            let result: ChatResult = try await openAI.chats(query: query)
            guard let text = result.choices.first?.message.content, !text.isEmpty else {
                throw LLMError.noContent
            }
            return text
        } catch {
            throw LLMError.underlying(error)
        }
    }

    // MARK: - Anthropic 兼容（SwiftAnthropic）

    private static func completeAnthropic(config: AIModelConfig,
                                           messages: [(role: String, content: String)],
                                           system: String) async throws -> String {
        // SwiftAnthropic 会把传入的 base URL 的 path 保留，然后自己补 `/v1/messages`。
        // 例如 `https://ark.cn-beijing.volces.com/api/coding` → `/api/coding/v1/messages`。
        let basePath = anthropicBaseURL(config.effectiveBaseURL)
        let service = AnthropicServiceFactory.service(
            apiKey: config.apiKey,
            apiVersion: "2023-06-01",
            basePath: basePath,
            betaHeaders: nil
        )

        let apiMessages: [MessageParameter.Message] = messages.map { m in
            let role: MessageParameter.Message.Role = (m.role == "assistant") ? .assistant : .user
            return MessageParameter.Message(role: role, content: .text(m.content))
        }

        let parameters = MessageParameter(
            model: .other(config.effectiveModel),
            messages: apiMessages,
            maxTokens: 2048,
            system: .text(system)
        )

        do {
            let response = try await service.createMessage(parameters)
            let text = response.content.compactMap { block -> String? in
                if case .text(let str, _) = block { return str }
                return nil
            }.joined(separator: "\n")
            guard !text.isEmpty else { throw LLMError.noContent }
            return text
        } catch {
            throw LLMError.underlying(error)
        }
    }

    // MARK: - URL 辅助

    /// 把 `https://host/path` 拆成 (scheme, host, path)，给 MacPaw 的 `host` / `basePath` 用。
    private static func splitBaseURL(_ base: String) -> (scheme: String, host: String, basePath: String) {
        guard let u = URL(string: base), let scheme = u.scheme, let host = u.host else {
            return ("https", "api.openai.com", "/v1")
        }
        return (scheme, host, u.path)
    }

    /// SwiftAnthropic 会把传入的 base URL 的 path 保留，然后自己补 `/v1/messages`。
    /// 例如：
    ///   - `https://api.anthropic.com` → `/v1/messages`
    ///   - `https://ark.cn-beijing.volces.com/api/coding` → `/api/coding/v1/messages`
    /// 因此不能 strip 掉 path，否则兼容端点（火山方舟 Coding Plan 等）会 404。
    private static func anthropicBaseURL(_ base: String) -> String {
        guard let u = URL(string: base), let scheme = u.scheme, let host = u.host else {
            return "https://api.anthropic.com"
        }
        var c = URLComponents()
        c.scheme = scheme
        c.host = host
        c.port = u.port
        c.path = u.path
        return c.string ?? "https://api.anthropic.com"
    }
}
