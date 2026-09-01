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
    private static let appIDKey = "GADApplicationIdentifier"
    private static let bannerAdUnitIDKey = "OdoroBannerAdUnitID"
    private static let googleSampleAppID = "ca-app-pub-3940256099942544~1458002511"
    private static let googleSampleBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"

    static var appID: String? {
        sanitizedID(
            Bundle.main.object(forInfoDictionaryKey: appIDKey) as? String,
            sampleID: googleSampleAppID
        )
    }

    static var bannerAdUnitID: String? {
        sanitizedID(
            Bundle.main.object(forInfoDictionaryKey: bannerAdUnitIDKey) as? String,
            sampleID: googleSampleBannerAdUnitID
        )
    }

    static var canServeAds: Bool {
        appID != nil && bannerAdUnitID != nil
    }

    private static func sanitizedID(_ rawValue: String?, sampleID: String) -> String? {
        guard let rawValue else { return nil }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            !trimmed.hasPrefix("$("),
            !trimmed.hasPrefix("REPLACE_WITH_")
        else {
            return nil
        }

        #if DEBUG
        return trimmed
        #else
        return trimmed == sampleID ? nil : trimmed
        #endif
    }
}

struct AdaptiveBannerAdView: View {
    var body: some View {
        if let adUnitID = AdMobConfiguration.bannerAdUnitID {
            #if canImport(GoogleMobileAds)
            GoogleAdaptiveBannerAdView(adUnitID: adUnitID)
            #else
            EmptyView()
            #endif
        } else {
            EmptyView()
        }
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
