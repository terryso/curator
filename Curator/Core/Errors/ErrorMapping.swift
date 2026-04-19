import Foundation

// MARK: - InfrastructureError → DomainError Mapping

extension InfrastructureError {
    /// Maps an infrastructure-layer error to a domain-layer error.
    func toDomainError() -> DomainError {
        switch self {
        case .folderAccessDenied:
            return .insufficientPermission(required: .read)
        case .folderScanFailed(let reason):
            return .invalidState(reason: reason)
        case .fileNotFound(let path):
            return .assetNotFound(AssetID(rawValue: path))
        case .fileWriteFailed(_, let reason):
            return .invalidState(reason: reason)
        case .bookmarkAccessFailed:
            return .insufficientPermission(required: .read)
        case .llmProviderUnavailable:
            return .analysisFailed(reason: "AI 服务暂时不可用")
        case .llmProviderError:
            return .analysisFailed(reason: "AI 分析失败")
        case .networkError:
            return .analysisFailed(reason: "网络连接失败")
        case .rateLimitExceeded:
            return .analysisFailed(reason: "AI 服务请求频率超限")
        case .cacheError(let reason):
            return .invalidState(reason: reason)
        }
    }
}

// MARK: - DomainError → UserFacingError Mapping

extension DomainError {
    /// Maps a domain-layer error to a user-facing error suitable for UI display.
    ///
    /// Never exposes technical details such as error domains, HTTP status codes,
    /// or internal identifiers. All messages are user-friendly.
    func toUserFacingError() -> UserFacingError {
        switch self {
        case .assetNotFound:
            return .readOnly(
                title: "未找到照片",
                message: "请求的照片无法找到，可能已被移动或删除。"
            )
        case .analysisFailed:
            return .retryable(
                title: "分析不可用",
                message: "无法分析照片，请稍后重试。"
            )
        case .insufficientPermission:
            return .permissionRequired(
                title: "需要访问权限",
                action: "请选择照片文件夹以授予访问权限"
            )
        case .operationCancelled:
            return .readOnly(
                title: "已取消",
                message: "操作已取消。"
            )
        case .invalidState:
            return .retryable(
                title: "出了点问题",
                message: "发生了意外错误，请重试。"
            )
        }
    }
}
