import Foundation
import os

public enum GeminiUsageError: Error, LocalizedError {
    case executableNotFound
    case executionFailed
    case invalidOutput
    
    public var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Gemini CLI executable not found at specified path."
        case .executionFailed:
            return "Failed to execute Gemini CLI command."
        case .invalidOutput:
            return "Could not parse Gemini CLI stats output."
        }
    }
}

public protocol GeminiUsageServiceProtocol: Sendable {
    func fetchUsage(executablePath: String) async throws -> GeminiUsage
}

public final class GeminiUsageService: GeminiUsageServiceProtocol, Sendable {
    private static let logger = Logger(subsystem: "com.ajaxjiang.Burnout", category: "GeminiUsageService")
    
    public init() {}
    
    public func fetchUsage(executablePath: String) async throws -> GeminiUsage {
        // We use zsh -l -c to load the user's shell profile (environment variables, paths, proxies)
        // This is crucial for node-based CLIs and tools requiring proxies.
        
        // Escape the executable path for shell
        let expandedPath = NSString(string: executablePath).expandingTildeInPath
        let escapedPath = expandedPath.replacingOccurrences(of: " ", with: "\\ ")
        
        // Fix for "env: node: No such file or directory":
        // The gemini executable is likely a symlink to a node script, and it needs 'node' in the PATH.
        // We implicitly add the directory of the gemini executable to the PATH, as node is usually there too.
        let executableDir = URL(fileURLWithPath: expandedPath).deletingLastPathComponent().path
        let escapedDir = executableDir.replacingOccurrences(of: " ", with: "\\ ")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // We prepend the executable's directory to PATH.
        // We use -l to load user profiles for proxies.
        // We set CI=true to discourage interactive prompts.
        // We use < /dev/null to ensure it doesn't wait for stdin.
        process.arguments = ["-l", "-c", "export CI=true; export PATH=\"\(escapedDir):$PATH\"; \(escapedPath) stats session < /dev/null"]
        
        // Ensure we capture output
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        do {
            try process.run()
        } catch {
            Self.logger.error("Failed to run gemini via zsh: \(error)")
            throw GeminiUsageError.executionFailed
        }
        
        // Read output asynchronously to prevent pipe deadlocks
        let outputTask = Task { pipe.fileHandleForReading.readDataToEndOfFile() }
        let errorTask = Task { errorPipe.fileHandleForReading.readDataToEndOfFile() }
        
        // Timeout handling
        let timeout: TimeInterval = 45.0
        let start = Date()
        
        // Polling for exit (simple approach for Process without async/await wrapper)
        // A better approach would be using a detached Task to sleep and kill, 
        // but simple polling loop in 0.1s increments is effective for short timeouts without complex concurrency.
        while process.isRunning {
            if Date().timeIntervalSince(start) > timeout {
                process.terminate()
                Self.logger.error("Gemini CLI timed out after \(timeout) seconds")
                throw NSError(domain: "GeminiUsage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Gemini CLI timed out"])
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
        
        let data = await outputTask.value
        let errorData = await errorTask.value
        
        let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
        let output = String(data: data, encoding: .utf8) ?? ""
        
        guard process.terminationStatus == 0 else {
            Self.logger.error("Gemini exited with status \(process.terminationStatus): \(errorString)")
            throw NSError(domain: "GeminiUsage", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Gemini CLI failed (\(process.terminationStatus)): \(errorString)"])
        }
        
        return parseOutput(output)
    }
    
    private func parseOutput(_ output: String) -> GeminiUsage {
        var models: [GeminiModelUsage] = []
        
        // Regex to match lines like:
        // │  gemini-2.5-flash-lite          4   97.7% (Resets in 22h 52m)
        // Groups: 1=Name, 2=Reqs, 3=Percentage, 4=ResetTime
        // using \S for non-whitespace, and handling potential spaces in "Resets in"
        let pattern = #"(gemini-\S+)\s+([\d-]+)\s+([\d.]+)%\s+\(Resets\s+in\s+([^)]+)\)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        
        output.enumerateLines { line, _ in
            guard let regex = regex else { return }
            let range = NSRange(location: 0, length: line.utf16.count)
            
            if let match = regex.firstMatch(in: line, options: [], range: range) {
                let nameRange = match.range(at: 1)
                let reqsRange = match.range(at: 2)
                let pctRange = match.range(at: 3)
                let resetRange = match.range(at: 4)
                
                if let nameRange = Range(nameRange, in: line),
                   let reqsRange = Range(reqsRange, in: line),
                   let pctRange = Range(pctRange, in: line),
                   let resetRange = Range(resetRange, in: line) {
                    
                    let name = String(line[nameRange])
                    let requestsStr = String(line[reqsRange])
                    let requests = Int(requestsStr) ?? 0
                    let percentage = Double(line[pctRange]) ?? 0.0
                    let resetsIn = String(line[resetRange])
                    
                    models.append(GeminiModelUsage(
                        name: name,
                        requests: requests,
                        usagePercentage: percentage,
                        resetsIn: resetsIn
                    ))
                }
            }
        }
        
        return GeminiUsage(models: models, lastUpdated: Date())
    }
}
