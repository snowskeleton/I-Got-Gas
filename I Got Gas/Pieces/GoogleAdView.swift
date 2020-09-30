//
//  GoogleAdView.swift
//  I Got Gas
//
//  Created by Isaac Lyons on 9/19/20.
//  Copyright © 2020 Blizzard Skeleton. All rights reserved.
//

import SwiftUI
import GoogleMobileAds
import UIKit



final private class BannerVC: UIViewControllerRepresentable  {

    func makeUIViewController(context: Context) -> UIViewController {
        let view = GADBannerView(adSize: kGADAdSizeBanner)

        let viewController = UIViewController()
        view.adUnitID = "ca-app-pub-3940256099942544/6300978111"
        view.rootViewController = viewController
        viewController.view.addSubview(view)
        viewController.view.frame = CGRect(origin: .zero, size: kGADAdSizeBanner.size)
        view.load(GADRequest())

        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct Banner:View{
    var body: some View{
        HStack{
            Spacer()
            BannerVC().frame(width: 320, height: 50, alignment: .center)
            Spacer()
        }
    }
}

struct Banner_Previews: PreviewProvider {
    static var previews: some View {
        Banner()
    }
}
//struct AdView: UIViewControllerRepresentable {
//
//
//
//    func makeUIView(context: UIViewRepresentableContext<AdView>) -> some GADBannerView {
//
//        let banner = GADBannerView(adSize: kGADAdSizeBanner)
//
//        banner.adUnitID = "ca-app-pub-3940256099942544/2934735716"
//        banner.rootViewController = UIApplication.shared.windows.first?.rootViewController
//        banner.load(GADRequest())
//        return banner
//    }
////    func updateUIView(_ uiView: GADBannerView, context: UIViewRepresentableContext<AdView>) {
////
////    }
//}

//final private class BannerVC: UIViewControllerRepresentable  {
//
//    func makeUIViewController(context: Context) -> UIViewController {
//        let view = GADBannerView(adSize: kGADAdSizeBanner)
//
//        let viewController = UIViewController()
//        view.adUnitID = "ca-app-pub-3940256099942544/2934735716"
//        view.rootViewController = viewController
//        viewController.view.addSubview(view)
//        viewController.view.frame = CGRect(origin: .zero, size: kGADAdSizeBanner.size)
//        view.load(GADRequest())
//
//        return viewController
//    }
//
//    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
//}
//
//struct Banner:View{
//    var body: some View{
//        HStack{
//            Spacer()
//            BannerVC().frame(width: 320, height: 50, alignment: .center)
//            Spacer()
//        }
//    }
//}
//
//struct Banner_Previews: PreviewProvider {
//    static var previews: some View {
//        Banner()
//    }
//}
