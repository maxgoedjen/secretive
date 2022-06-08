import Foundation

func mainActorWrapped(_ f: @escaping @MainActor () -> Void) -> () -> Void {
    return {
        DispatchQueue.main.async {
            f()
        }
    }
}

func mainActorWrapped<T: Sendable>(_ f: @escaping @MainActor (T) -> Void) -> (T) -> Void {
    return { x in
        DispatchQueue.main.async {
            f(x)
        }
    }
}
