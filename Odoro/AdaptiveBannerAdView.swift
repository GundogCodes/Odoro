//
//  AdaptiveBannerAdView.swift
//  Odoro
//

import SwiftUI
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

enum AdMobConfiguration {
    static let bannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
}

struct AdaptiveBannerAdView: View {
    var body: some View {
        #if canImport(GoogleMobileAds)
        GoogleAdaptiveBannerAdView(adUnitID: AdMobConfiguration.bannerAdUnitID)
        #else
        EmptyView()
        #endif
    }
}

#if canImport(GoogleMobileAds)
private struct GoogleAdaptiveBannerAdView: View {
    let adUnitID: String
    @State private var bannerSize = CGSize(width: 320, height: 50)

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 1)
            let adSize = currentOrientationAnchoredAdaptiveBanner(width: availableWidth)

            BannerViewContainer(adSize: adSize, adUnitID: adUnitID)
                .frame(width: adSize.size.width, height: adSize.size.height)
                .frame(maxWidth: .infinity)
                .onAppear {
                    bannerSize = adSize.size
                }
                .onChange(of: proxy.size.width) { _, newWidth in
                    bannerSize = currentOrientationAnchoredAdaptiveBanner(width: max(newWidth, 1)).size
                }
        }
        .frame(height: bannerSize.height)
    }
}

private struct BannerViewContainer: UIViewRepresentable {
    let adSize: AdSize
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.odoroRootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        banner.adSize = adSize
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.odoroRootViewController

        if context.coordinator.lastLoadedSize != adSize.size {
            context.coordinator.lastLoadedSize = adSize.size
            banner.load(Request())
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(initialSize: adSize.size)
    }

    final class Coordinator {
        var lastLoadedSize: CGSize

        init(initialSize: CGSize) {
            self.lastLoadedSize = initialSize
        }
    }
}

private extension UIApplication {
    var odoroRootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
#endif
