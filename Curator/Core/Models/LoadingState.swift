import Foundation

/// Generic loading state enum for tracking asynchronous resource loading.
///
/// Used across the app to represent the lifecycle of data loading:
/// idle → loading → loaded(T) or failed(DomainError).
///
/// Conforms to Sendable when T is Sendable, enabling safe use across
/// concurrency domains.
enum LoadingState<T: Sendable>: Sendable {
    case idle
    case loading
    case loaded(T)
    case failed(DomainError)
}
