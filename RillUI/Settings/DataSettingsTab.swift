import SwiftUI

struct DataSettingsTab: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var isConfirmingReset = false
    @State private var isConfirmingPinsClear = false

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard(title: "Usage") {
                HStack {
                    Text("History")
                        .font(.system(size: 13))
                    Spacer()
                    Text("App opens and result executions")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                SettingsCardDivider()

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Button("Reset Usage History") {
                            isConfirmingReset = true
                        }
                        Spacer()
                        Button("Reveal Data File") {
                            viewModel.revealUsageData()
                        }
                    }
                    Text("Resetting clears suggested apps, frecency ranking, and favorites.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            SettingsCard(title: "Favorites") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Button("Clear Pinned Items") {
                            isConfirmingPinsClear = true
                        }
                        Spacer()
                    }
                    Text("Unpins everything. Frecency ranking and suggested apps are kept.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog(
            "Reset usage history?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                viewModel.clearUsageHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Suggested apps, frecency ranking, and favorites are cleared. This cannot be undone.")
        }
        .confirmationDialog(
            "Clear pinned items?",
            isPresented: $isConfirmingPinsClear,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) {
                viewModel.clearPinnedItems()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every favorite is unpinned. Usage history stays.")
        }
    }
}
