//
//  WelcomeView.swift
//  TollFund
//
//  Created on Date.
//

import SwiftUI

struct WelcomeView: View {
    @Binding var showWelcome: Bool
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // 封面图片
                if let image = UIImage(named: "cover-image") {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 250, maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                } else {
                    // 备用图标
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                }
                
                // 欢迎内容
                VStack(spacing: 16) {
                    Text("欢迎来到 TollFund")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("智能挑战奖励系统")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    Text("通过完成每日任务和挑战来获得奖励\n让自己的成长更有动力！")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // 开始按钮
                VStack(spacing: 12) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showWelcome = false
                        }
                    }) {
                        Text("开始使用")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                    }
                    .padding(.horizontal, 40)
                    
                    Button(action: {
                        showWelcome = false
                    }) {
                        Text("跳过")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer().frame(height: 50)
            }
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(showWelcome: .constant(true))
    }
}
