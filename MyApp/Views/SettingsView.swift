import SwiftUI

/// Rendering options shared by Draw and Convert, plus app info.
struct SettingsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var model = appModel
        NavigationStack {
            Form {
                Section("선") {
                    ColorPicker("색상", selection: $model.renderSettings.strokeColor)
                    LabeledContent("굵기") {
                        Text(model.renderSettings.strokeWidth.formatted(.number.precision(.fractionLength(1))))
                            .monospacedDigit()
                    }
                    Slider(value: $model.renderSettings.strokeWidth, in: 0.5...4.0, step: 0.1)
                    Toggle("색상 순환", isOn: $model.renderSettings.isColorCycleEnabled)
                    Text("켜면 레이어(k) 진행에 따라 선의 색이 스펙트럼을 따라 바뀝니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("배경") {
                    Toggle("어두운 배경", isOn: $model.renderSettings.isDarkBackground)
                }

                Section("정보") {
                    LabeledContent("앱", value: "Mathigram")
                    LabeledContent("버전", value: "0.1")
                    Text("수식으로 그리고, 그림을 수식으로. Apache License 2.0으로 배포됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("설정")
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppModel())
}
