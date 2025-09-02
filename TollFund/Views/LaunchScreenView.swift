//
//  LaunchScreenView.swift
//  TollFund
//
//  Created on Date.
//

import SwiftUI

struct LaunchScreenView: View {
    @State private var isActive = false
    @State private var size = 0.8
    @State private var opacity = 0.5
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack {
                // 背景渐变
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 封面图片
                    if let image = UIImage(named: "cover-image") {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 300, maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    } else {
                        // 备用图标
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 100))
                            .foregroundColor(.white)
                    }
                    
                    // 应用标题
                    VStack(spacing: 8) {
                        Text("TollFund")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("智能挑战奖励系统")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // 版本信息
                    Text("v1.0")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .scaleEffect(size)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 1.2)) {
                        self.size = 0.9
                        self.opacity = 1.0
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.isActive = true
                    }
                }
            }
        }
    }
}

struct LaunchScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreenView()
    }
}
