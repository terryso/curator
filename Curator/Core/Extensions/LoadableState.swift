import SwiftUI

/// SwiftUI View extension for LoadingState-based conditional rendering.
///
/// Provides a convenience API for switching views based on LoadingState cases,
/// reducing boilerplate in view code.
extension View {
    /// Conditionally renders content based on LoadingState.
    ///
    /// - Parameters:
    ///   - state: The current LoadingState value
    ///   - idle: View to show when idle
    ///   - loading: View to show during loading
    ///   - loaded: View builder receiving the loaded value
    ///   - failed: View builder receiving the DomainError
    @ViewBuilder
    func loadable<T, Content: View>(
        _ state: LoadingState<T>,
        idle: @escaping () -> Content,
        loading: @escaping () -> Content,
        loaded: @escaping (T) -> Content,
        failed: @escaping (DomainError) -> Content
    ) -> some View {
        switch state {
        case .idle:
            idle()
        case .loading:
            loading()
        case .loaded(let value):
            loaded(value)
        case .failed(let error):
            failed(error)
        }
    }
}
