//
//  PillPopover.swift
//  RetireSmartIRA

import SwiftUI

struct NumericStepperPopover: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String
    let onCommit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(title).font(.headline)
            HStack {
                Button { value = max(range.lowerBound, value - step) } label: {
                    Image(systemName: "minus.circle.fill").font(.title2)
                }
                Text(format(value)).font(.title2.weight(.bold)).frame(minWidth: 100)
                Button { value = min(range.upperBound, value + step) } label: {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
            }
            Button("Done", action: onCommit).buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(minWidth: 240)
    }
}

struct EnumPickerPopover<T: Hashable>: View {
    let title: String
    @Binding var selection: T
    let options: [(label: String, value: T)]
    let onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(options.indices, id: \.self) { idx in
                let opt = options[idx]
                Button {
                    selection = opt.value
                    onCommit()
                } label: {
                    HStack {
                        Text(opt.label)
                        Spacer()
                        if selection == opt.value {
                            Image(systemName: "checkmark").foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(minWidth: 220)
    }
}
