//
//  main.swift
//  taxsim-refresh
//
//  Posts scenarios from RetireSmartIRATests/Fixtures/taxsim-scenarios.json to
//  NBER's TAXSIM-35 (https://taxsim.nber.org/taxsim35/redirect.cgi) and writes
//  the parsed responses to RetireSmartIRATests/Fixtures/taxsim-expected.json.
//
//  Run locally: `swift run` (from tools/taxsim-refresh/). Network required.
//  NOT for CI. See README.md.
//

import Foundation

// MARK: - Locate the worktree root

// Source file lives at <root>/tools/taxsim-refresh/Sources/taxsim-refresh/main.swift
// so the worktree root is four directory parents up from this file.
let thisFile = URL(fileURLWithPath: #filePath)
let worktreeRoot = thisFile
    .deletingLastPathComponent()  // taxsim-refresh
    .deletingLastPathComponent()  // Sources
    .deletingLastPathComponent()  // taxsim-refresh
    .deletingLastPathComponent()  // tools
    .deletingLastPathComponent()  // <root>

let scenariosURL = worktreeRoot
    .appendingPathComponent("RetireSmartIRATests/Fixtures/taxsim-scenarios.json")
let expectedURL = worktreeRoot
    .appendingPathComponent("RetireSmartIRATests/Fixtures/taxsim-expected.json")

print("[taxsim-refresh] root         = \(worktreeRoot.path)")
print("[taxsim-refresh] reading      \(scenariosURL.lastPathComponent)")
print("[taxsim-refresh] will write   \(expectedURL.lastPathComponent)")

// MARK: - Decode scenarios (loose schema; we only need a few fields)

struct ScenarioInput: Decodable {
    let id: Int
    let name: String
    let year: Int
    let state_soi: Int
    let state_enum: String
    let filing_status: String
    let mstat: Int
    let primary_age: Int
    let spouse_age: Int
    let wages_primary: Double
    let wages_spouse: Double
    let pensions: Double
    let gssi: Double
    let intrec: Double
    let dividends: Double
    let stcg: Double
    let ltcg: Double
}

struct ScenarioFile: Decodable {
    let scenarios: [ScenarioInput]
}

let rawScenarios = try Data(contentsOf: scenariosURL)
let file = try JSONDecoder().decode(ScenarioFile.self, from: rawScenarios)
print("[taxsim-refresh] loaded       \(file.scenarios.count) scenarios")

// MARK: - Build a CSV with every scenario as one record

let header = [
    "taxsimid","year","state","mstat","page","sage","depx",
    "pwages","swages",
    "pensions","gssi",
    "intrec","dividends",
    "stcg","ltcg",
    "otherprop","nonprop","proptax","otheritem","mortgage"
]
var csv = header.joined(separator: ",") + "\n"
for s in file.scenarios {
    let row: [String] = [
        "\(s.id)", "\(s.year)", "\(s.state_soi)", "\(s.mstat)",
        "\(s.primary_age)", "\(s.spouse_age)", "0",
        "\(Int(s.wages_primary))", "\(Int(s.wages_spouse))",
        "\(Int(s.pensions))", "\(Int(s.gssi))",
        "\(Int(s.intrec))", "\(Int(s.dividends))",
        "\(Int(s.stcg))", "\(Int(s.ltcg))",
        "0","0","0","0","0"
    ]
    csv += row.joined(separator: ",") + "\n"
}

// MARK: - Multipart POST

let endpoint = URL(string: "https://taxsim.nber.org/taxsim35/redirect.cgi")!
let boundary = "----taxsimrefresh\(UUID().uuidString)"

var body = Data()
func appendString(_ s: String) { body.append(s.data(using: .utf8)!) }
appendString("--\(boundary)\r\n")
appendString("Content-Disposition: form-data; name=\"txpydata.raw\"; filename=\"txpydata.raw\"\r\n")
appendString("Content-Type: text/plain\r\n\r\n")
appendString(csv)
appendString("\r\n--\(boundary)--\r\n")

var request = URLRequest(url: endpoint)
request.httpMethod = "POST"
request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
request.httpBody = body
request.timeoutInterval = 60

print("[taxsim-refresh] POST          \(endpoint.absoluteString)  (\(csv.count) bytes CSV)")

let sema = DispatchSemaphore(value: 0)
var responseData: Data? = nil
var responseError: Error? = nil
var httpStatus: Int = 0

let task = URLSession.shared.dataTask(with: request) { data, resp, err in
    responseData = data
    responseError = err
    if let http = resp as? HTTPURLResponse { httpStatus = http.statusCode }
    sema.signal()
}
task.resume()
sema.wait()

if let err = responseError {
    FileHandle.standardError.write("[taxsim-refresh] ERROR: network: \(err)\n".data(using: .utf8)!)
    exit(2)
}
guard let data = responseData, let body = String(data: data, encoding: .utf8) else {
    FileHandle.standardError.write("[taxsim-refresh] ERROR: empty/non-utf8 response (status \(httpStatus))\n".data(using: .utf8)!)
    exit(3)
}
print("[taxsim-refresh] HTTP \(httpStatus)        (\(data.count) bytes response)")

if body.contains("STOP") || body.contains("Abandoning processing") {
    FileHandle.standardError.write("[taxsim-refresh] ERROR: TAXSIM rejected at least one record. Full response:\n".data(using: .utf8)!)
    FileHandle.standardError.write(body.data(using: .utf8)!)
    exit(4)
}

// MARK: - Parse the response CSV

// First line is header: taxsimid,year,state,fiitax,siitax,fica,frate,srate,ficar,tfica
// Subsequent lines: one per scenario.

struct ExpectedRow: Encodable {
    let taxsimid: Int
    let name: String
    let year: Int
    let state_soi: Int
    let fiitax: Double
    let siitax: Double
    let fica: Double
    let frate: Double
    let srate: Double
}

let lines = body.split(separator: "\n", omittingEmptySubsequences: true).map { String($0) }
guard lines.count >= 2 else {
    FileHandle.standardError.write("[taxsim-refresh] ERROR: response had no data rows\n".data(using: .utf8)!)
    FileHandle.standardError.write(body.data(using: .utf8)!)
    exit(5)
}
let headerCells = lines[0].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
func idx(_ name: String) -> Int? { headerCells.firstIndex(of: name) }
guard let iId = idx("taxsimid"), let iYear = idx("year"), let iState = idx("state"),
      let iFii = idx("fiitax"), let iSii = idx("siitax"),
      let iFica = idx("fica"), let iFrate = idx("frate"), let iSrate = idx("srate") else {
    FileHandle.standardError.write("[taxsim-refresh] ERROR: response header missing columns: \(headerCells)\n".data(using: .utf8)!)
    exit(6)
}

let byId: [Int: ScenarioInput] = Dictionary(uniqueKeysWithValues: file.scenarios.map { ($0.id, $0) })
var rows: [ExpectedRow] = []
for line in lines.dropFirst() {
    let cells = line.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    if cells.count < headerCells.count { continue }
    // TAXSIM emits "1." style trailing dot on integers; strip it.
    let idStr = cells[iId].replacingOccurrences(of: ".", with: "")
    guard let id = Int(idStr) else { continue }
    let scenario = byId[id]
    let row = ExpectedRow(
        taxsimid: id,
        name: scenario?.name ?? "<unknown id \(id)>",
        year: Int(cells[iYear]) ?? 0,
        state_soi: Int(Double(cells[iState]) ?? 0),
        fiitax: Double(cells[iFii]) ?? 0,
        siitax: Double(cells[iSii]) ?? 0,
        fica: Double(cells[iFica]) ?? 0,
        frate: Double(cells[iFrate]) ?? 0,
        srate: Double(cells[iSrate]) ?? 0
    )
    rows.append(row)
}
print("[taxsim-refresh] parsed       \(rows.count) rows")

if rows.count != file.scenarios.count {
    FileHandle.standardError.write("[taxsim-refresh] WARN: parsed \(rows.count) rows but sent \(file.scenarios.count) scenarios\n".data(using: .utf8)!)
}

// MARK: - Write the expected fixture

struct ExpectedFile: Encodable {
    let _meta: Meta
    let rows: [ExpectedRow]
    struct Meta: Encodable {
        let source: String
        let endpoint: String
        let refreshed_at: String
        let note: String
    }
}

let isoFormatter = ISO8601DateFormatter()
let payload = ExpectedFile(
    _meta: .init(
        source: "NBER TAXSIM-35",
        endpoint: endpoint.absoluteString,
        refreshed_at: isoFormatter.string(from: Date()),
        note: "Regenerated by tools/taxsim-refresh. Do not edit by hand. fiitax includes federal income tax + AMT + capital-gains adjustments + NIIT per TAXSIM defaults; siitax is the resident-state income tax. TAXSIM federal logic is coded only through tax year 2023; state logic varies."
    ),
    rows: rows
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let outData = try encoder.encode(payload)
try outData.write(to: expectedURL)
print("[taxsim-refresh] wrote        \(expectedURL.path)")
print("[taxsim-refresh] OK")
exit(0)
