//
//  AsyncMutex.swift
//  Runner
//
//  Created by Callum Moffat on 2026-01-24.
//

public actor AsyncMutex<Resource> {
    private var resource: Resource

    private var locked: Bool = false

    // FIFO queue
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(_ resource: Resource) {
        self.resource = resource
    }

    func acquire() async -> Void {
        if !locked && waiters.isEmpty {
            locked = true
            return
        }

        // Enqueue and suspend. FIFO is preserved by `append` + `removeFirst`.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            waiters.append(cont)
        }
        // When resumed, we own the lock.
    }

    func release() {
        // Baton-passing: resume next waiter (FIFO) or unlock.
        if waiters.isEmpty {
            locked = false
            return
        }
        let cont = waiters.removeFirst()
        // Keep `locked = true` while handing off.
        cont.resume()
    }

    func withResource<T>(_ body: (Resource) async throws -> T) async rethrows -> T {
        await acquire()
        defer { Task { release() }}
        return try await body(resource)
    }
}
