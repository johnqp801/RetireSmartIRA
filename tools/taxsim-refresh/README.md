# taxsim-refresh

Independent-oracle fixture refresh tool for the RetireSmartIRA tax engine.

## What this is

Posts the scenarios in `RetireSmartIRATests/Fixtures/taxsim-scenarios.json` to NBER's
TAXSIM-35 web API and writes the responses into
`RetireSmartIRATests/Fixtures/taxsim-expected.json`. The test target
(`TaxsimOracleTests.swift`) reads BOTH fixtures and does pure-local diffing — it
never hits the network.

This is the "Part 1" oracle harness added after a tester (Jonggie F.) reported the
same PA state-tax bug twice (v1.8.2 and v1.8.3). The 951 self-referential tests
both authored by Claude let the bug slip through; TAXSIM-35 has been the academic
standard since 1974 (PolicyEngine US, 1200+ papers) and gives us an independent
check.

## How to run

```bash
cd tools/taxsim-refresh
swift run
```

Network required. Don't run in CI — TAXSIM is a research host, and we keep the
fixture checked in so test runs are deterministic. Refresh by hand when the input
scenarios change.

## TAXSIM-35 API contract (verified 2026-05-19)

- Endpoint: `POST https://taxsim.nber.org/taxsim35/redirect.cgi`
- Multipart upload, form field name: `txpydata.raw`
- Body: CSV with header row (variable names; order is free) and one record per scenario
- Year cap: TAXSIM-35 federal logic ends at tax year 2023. Sending `year >= 2024`
  returns `TAXSIM: Federal tax calculator available 1960 - 2023 only.` followed by
  `STOP 1`. The harness therefore sends year=2023 to both TAXSIM and to the engine
  (we set `dm.profile.currentYear = 2023`) so neither side has a year-mismatch advantage.

### Manual curl smoke test

```bash
cat > /tmp/taxsim_test.csv <<'CSV'
taxsimid,year,state,mstat,page,sage,depx,pwages,swages,pensions,gssi,intrec,dividends,stcg,ltcg,otherprop,nonprop,proptax,otheritem,mortgage
1,2023,39,1,65,0,0,0,0,50000,0,0,0,0,0,0,0,0,0,0
CSV
curl -s -F "txpydata.raw=@/tmp/taxsim_test.csv" https://taxsim.nber.org/taxsim35/redirect.cgi
```

Expected output (one row per record, plus a header):
```
taxsimid,year,state,fiitax,siitax,fica,frate,srate,ficar,tfica
1.,2023,39,3908.00,3196.78,0.00,12.00,7.70,15.30,0.00
```

(That siitax=$3,196.78 for PA is itself a known divergence — TAXSIM treats the
`pensions` field as taxable in PA, while real PA law and our engine exempt
retirement-age IRA distributions. Documented in `TaxsimOracleTests.swift`.)

## State SOI codes

DC counts as state 9, so the codes shift up by one starting at FL=10. PA=39,
TX=44, NY=33, CA=5. See `https://taxsim.nber.org/statesoi.html`.

## Exit codes

- 0: all scenarios returned a parseable row
- non-zero: at least one scenario errored (HTTP failure, STOP from TAXSIM, parse fail)
