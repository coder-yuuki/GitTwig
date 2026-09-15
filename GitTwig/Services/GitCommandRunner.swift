import Foundation

struct GitCommandResult: Equatable {
    var stdout: String
    var stderr: String
    var exitCode: Int32
}

enum GitCommandError: LocalizedError {
    case launchFailed(String, String)
    case timedOut([String])
    case nonZeroExit([String], Int32, String)

    var errorDescription: String? {
        switch self {
        case let .launchFailed(executable, message):
            return "Could not launch \(executable): \(message)"
        case let .timedOut(arguments):
            return "Git command timed out: git \(arguments.joined(separator: " "))"
        case let .nonZeroExit(arguments, exitCode, stderr):
            let reason = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if reason.isEmpty {
                return "Git command failed with exit code \(exitCode): git \(arguments.joined(separator: " "))"
            }
            return reason
        }
    }
}

final class GitCommandRunner {
    private struct Executable {
        var path: String
    }

    private let executables: [Executable] = [
        Executable(path: "/usr/bin/git"),
        Executable(path: "/opt/homebrew/bin/git"),
        Executable(path: "/usr/local/bin/git")
    ]

    private let environment: [String: String] = [
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_OPTIONAL_LOCKS": "0",
        "GIT_PAGER": "cat",
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_SSH_COMMAND": "ssh -oBatchMode=yes",
        "LC_ALL": "C",
        "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"
    ]

    func runGit(arguments: [String], timeout: TimeInterval = 6) async throws -> GitCommandResult {
        var lastLaunchError: Error?

        for executable in executables {
            do {
                return try await run(
                    executable: executable.path,
                    arguments: arguments,
                    displayedArguments: arguments,
                    timeout: timeout
                )
            } catch let error as GitCommandError {
                if case .launchFailed = error {
                    lastLaunchError = error
                    continue
                }
                throw error
            } catch {
                lastLaunchError = error
            }
        }

        throw lastLaunchError ?? GitCommandError.launchFailed("git", "git executable was not found")
    }

    private func run(
        executable: String,
        arguments: [String],
        displayedArguments: [String],
        timeout: TimeInterval
    ) async throws -> GitCommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            var commandEnvironment = environment
            for key in ["HOME", "SSH_AUTH_SOCK", "TMPDIR"] {
                commandEnvironment[key] = ProcessInfo.processInfo.environment[key]
            }
            process.environment = commandEnvironment

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let output = GitOutputCollector()
            let readers = DispatchGroup()
            readers.enter()
            DispatchQueue.global(qos: .utility).async {
                output.setStdout(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
                readers.leave()
            }
            readers.enter()
            DispatchQueue.global(qos: .utility).async {
                output.setStderr(stderrPipe.fileHandleForReading.readDataToEndOfFile())
                readers.leave()
            }
            let completion = GitCommandCompletion(continuation: continuation)

            let timeoutWorkItem = DispatchWorkItem {
                guard !completion.hasResumed else {
                    return
                }

                if process.isRunning {
                    process.terminate()
                }
                completion.resume(.failure(GitCommandError.timedOut(displayedArguments)))
            }

            process.terminationHandler = { terminatedProcess in
                timeoutWorkItem.cancel()

                guard !completion.hasResumed else {
                    return
                }

                readers.wait()
                let stdoutData = output.stdout
                let stderrData = output.stderr
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                let exitCode = terminatedProcess.terminationStatus
                let result = GitCommandResult(stdout: stdout, stderr: stderr, exitCode: exitCode)

                if exitCode == 0 {
                    completion.resume(.success(result))
                } else {
                    completion.resume(.failure(GitCommandError.nonZeroExit(displayedArguments, exitCode, stderr)))
                }
            }

            do {
                try process.run()
                DispatchQueue.global(qos: .utility).asyncAfter(
                    deadline: .now() + timeout,
                    execute: timeoutWorkItem
                )
            } catch {
                timeoutWorkItem.cancel()
                try? stdoutPipe.fileHandleForWriting.close()
                try? stderrPipe.fileHandleForWriting.close()
                completion.resume(.failure(GitCommandError.launchFailed(executable, error.localizedDescription)))
            }
        }
    }
}

private final class GitCommandCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<GitCommandResult, Error>

    init(continuation: CheckedContinuation<GitCommandResult, Error>) {
        self.continuation = continuation
    }

    var hasResumed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didResume
    }

    func resume(_ result: Result<GitCommandResult, Error>) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }
        didResume = true
        lock.unlock()

        continuation.resume(with: result)
    }
}


private final class GitOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var out = Data()
    private var err = Data()
    func setStdout(_ data: Data) { lock.lock(); defer { lock.unlock() }; out = data }
    func setStderr(_ data: Data) { lock.lock(); defer { lock.unlock() }; err = data }
    var stdout: Data { lock.lock(); defer { lock.unlock() }; return out }
    var stderr: Data { lock.lock(); defer { lock.unlock() }; return err }
}
