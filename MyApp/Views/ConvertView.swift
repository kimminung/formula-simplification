import SwiftUI

/// Image → formula. Photo import and Fourier fitting land in a later phase.
struct ConvertView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "사진을 수식으로 변환",
                systemImage: "wand.and.stars",
                description: Text("사진을 선택하면 윤곽을 추출해 삼각함수 급수(푸리에 급수)로 근사합니다. 이 기능은 다음 단계에서 구현됩니다.")
            )
            .navigationTitle("변환")
        }
    }
}

#Preview {
    ConvertView()
        .environment(AppModel())
}
