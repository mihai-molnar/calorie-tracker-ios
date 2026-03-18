import SwiftUI

struct ShimmerView: View {
    var width: CGFloat = 100
    var height: CGFloat = 14

    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color(.systemGray4), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: phase * width)
            )
            .clipShape(RoundedRectangle(cornerRadius: height / 2))
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}
