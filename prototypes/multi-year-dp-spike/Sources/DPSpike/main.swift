import Foundation

// MARK: - Discretization

let yearCount = 30
let bracketBucketCount = 7      // 2026 federal brackets: 10/12/22/24/32/35/37
let irmaaTierCount = 6
let rothBalanceBucketCount = 20
let actionLevels = 10           // discretized Roth conversion amounts

let totalStates = yearCount * bracketBucketCount * irmaaTierCount * rothBalanceBucketCount
print("Total states: \(totalStates)")
print("Total transitions per pass: ~\(totalStates * actionLevels)")

// MARK: - State indexing

@inline(__always)
func stateIndex(_ year: Int, _ bracket: Int, _ irmaa: Int, _ roth: Int) -> Int {
    return ((year * bracketBucketCount + bracket) * irmaaTierCount + irmaa) * rothBalanceBucketCount + roth
}

// MARK: - DP table

var dp = [Double](repeating: 0, count: totalStates)

// MARK: - Backward induction

let startTime = Date()

for year in (0..<yearCount).reversed() {
    for bracket in 0..<bracketBucketCount {
        for irmaa in 0..<irmaaTierCount {
            for roth in 0..<rothBalanceBucketCount {
                let s = stateIndex(year, bracket, irmaa, roth)

                var bestCost = Double.infinity
                for action in 0..<actionLevels {
                    // Synthetic transition cost: action x 1000 (placeholder for real tax computation)
                    let transitionCost = Double(action) * 1000.0

                    if year == yearCount - 1 {
                        bestCost = min(bestCost, transitionCost)
                    } else {
                        // Synthetic next-state mapping (real engine would update bracket/irmaa/roth based on action)
                        let nextS = stateIndex(year + 1, bracket, irmaa, min(roth + action / 5, rothBalanceBucketCount - 1))
                        bestCost = min(bestCost, transitionCost + dp[nextS])
                    }
                }
                dp[s] = bestCost
            }
        }
    }
}

let elapsed = Date().timeIntervalSince(startTime)
print("DP backward induction: \(String(format: "%.3f", elapsed)) seconds")
print("DP[0] = \(dp[0])")

// MARK: - Stress variant -- 4x state size (run with --stress flag)

if CommandLine.arguments.contains("--stress") {
    print("\n--- STRESS VARIANT (4x state size) ---")
    let stressRothBuckets = 80
    let stressTotalStates = yearCount * bracketBucketCount * irmaaTierCount * stressRothBuckets
    print("Stress total states: \(stressTotalStates)")

    var stressDp = [Double](repeating: 0, count: stressTotalStates)

    func stressIndex(_ year: Int, _ bracket: Int, _ irmaa: Int, _ roth: Int) -> Int {
        return ((year * bracketBucketCount + bracket) * irmaaTierCount + irmaa) * stressRothBuckets + roth
    }

    let stressStart = Date()
    for year in (0..<yearCount).reversed() {
        for bracket in 0..<bracketBucketCount {
            for irmaa in 0..<irmaaTierCount {
                for roth in 0..<stressRothBuckets {
                    let s = stressIndex(year, bracket, irmaa, roth)
                    var bestCost = Double.infinity
                    for action in 0..<actionLevels {
                        let transitionCost = Double(action) * 1000.0
                        if year == yearCount - 1 {
                            bestCost = min(bestCost, transitionCost)
                        } else {
                            let nextS = stressIndex(year + 1, bracket, irmaa, min(roth + action / 5, stressRothBuckets - 1))
                            bestCost = min(bestCost, transitionCost + stressDp[nextS])
                        }
                    }
                    stressDp[s] = bestCost
                }
            }
        }
    }
    let stressElapsed = Date().timeIntervalSince(stressStart)
    print("Stress DP backward induction: \(String(format: "%.3f", stressElapsed)) seconds")
}
