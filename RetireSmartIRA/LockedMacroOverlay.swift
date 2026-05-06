//
//  LockedMacroOverlay.swift
//  RetireSmartIRA

import SwiftUI

struct LockedMacroOverlay: View {
    let onSetUp: () -> Void
    let onDismiss: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Use side-by-side cards when the available width is wide enough.
    /// On macOS horizontalSizeClass is always `.regular`, so we also gate
    /// on a geometry reader threshold of 600 pt.
    var body: some View {
        GeometryReader { geo in
            let useHStack = geo.size.width >= 600
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 52, weight: .light))
                            .foregroundColor(.blue)

                        Text("How would you like to start?")
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }

                    // Cards
                    if useHStack {
                        HStack(alignment: .top, spacing: 16) {
                            multiYearCard
                            thisYearCard
                        }
                    } else {
                        VStack(spacing: 16) {
                            multiYearCard
                            thisYearCard
                        }
                    }
                }
                .padding(28)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: geo.size.height)
            }
        }
        .background(Color(PlatformColor.systemBackground))
        .cornerRadius(14)
        .shadow(radius: 8)
        .padding()
    }

    // MARK: - Multi-year card (left / top)

    private var multiYearCard: some View {
        ChoiceCard(
            iconName: "calendar",
            iconColor: .blue,
            title: "Multi-year strategy",
            description: "Project your taxes decades ahead. See exactly when to convert, claim Social Security, and minimize RMDs.",
            buttonLabel: "Get started →",
            buttonAccent: .blue,
            recommendedLabel: "Recommended for most users",
            action: onSetUp
        )
    }

    // MARK: - This-year card (right / bottom)

    private var thisYearCard: some View {
        ChoiceCard(
            iconName: "bolt",
            iconColor: Color.secondary,
            title: "This year only",
            description: "Optimize this year's taxes now. You can unlock the full strategy anytime.",
            buttonLabel: "Start planning",
            buttonAccent: Color.secondary,
            recommendedLabel: nil,
            action: onDismiss
        )
    }
}

// MARK: - ChoiceCard

private struct ChoiceCard: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let description: String
    let buttonLabel: String
    let buttonAccent: Color
    let recommendedLabel: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Card body
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: iconName)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Button(buttonLabel, action: action)
                    .buttonStyle(ChoiceButtonStyle(accent: buttonAccent))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(PlatformColor.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)

            // Recommended label sits outside the card so it doesn't affect card height
            if let label = recommendedLabel {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 6)
            } else {
                // Reserve equal vertical space so both columns stay aligned
                Text(" ")
                    .font(.caption)
                    .padding(.top, 6)
                    .hidden()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ChoiceButtonStyle

private struct ChoiceButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundColor(accent == Color.secondary ? Color.primary : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(accent == Color.secondary
                          ? Color.secondary.opacity(0.12)
                          : accent)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
