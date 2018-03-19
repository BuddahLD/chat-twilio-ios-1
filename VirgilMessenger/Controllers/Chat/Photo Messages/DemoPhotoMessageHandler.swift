/*
 The MIT License (MIT)

 Copyright (c) 2015-present Badoo Trading Limited.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/

import Foundation
import ChattoAdditions
import PKHUD

class DemoPhotoMessageHandler: NSObject, BaseMessageInteractionHandlerProtocol {
    func userDidSelectMessage(viewModel: DemoPhotoMessageViewModel) {}

    func userDidDeselectMessage(viewModel: DemoPhotoMessageViewModel) {}

    private let baseHandler: BaseMessageHandler
    private let presenterController: UIViewController
    init (baseHandler: BaseMessageHandler, presenterController: UIViewController) {
        self.baseHandler = baseHandler
        self.presenterController = presenterController

        super.init()
    }

    func userDidTapOnFailIcon(viewModel: DemoPhotoMessageViewModel, failIconView: UIView) {
        self.baseHandler.userDidTapOnFailIcon(viewModel: viewModel)
    }

    func userDidTapOnAvatar(viewModel: DemoPhotoMessageViewModel) {
        self.baseHandler.userDidTapOnAvatar(viewModel: viewModel)
    }

    func userDidTapOnBubble(viewModel: DemoPhotoMessageViewModel) {
        self.baseHandler.userDidTapOnBubble(viewModel: viewModel)
        self.imageTapped(viewModel.fakeImage)
    }

    func userDidBeginLongPressOnBubble(viewModel: DemoPhotoMessageViewModel) {
        self.baseHandler.userDidBeginLongPressOnBubble(viewModel: viewModel)
        self.showSaveImageAlert(viewModel.fakeImage)
    }

    func userDidEndLongPressOnBubble(viewModel: DemoPhotoMessageViewModel) {
        self.baseHandler.userDidEndLongPressOnBubble(viewModel: viewModel)
    }

    private func showSaveImageAlert(_ image: UIImage) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Save to Camera Roll", style: .default) { _ in
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        self.presenterController.present(alert, animated: true)
    }

    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            let ac = UIAlertController(title: "Save error", message: error.localizedDescription, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            self.presenterController.present(ac, animated: true)
        } else {
            HUD.flash(.success)
        }
    }

    private func imageTapped(_ image: UIImage) {
        self.presenterController.view.endEditing(true)
        let newImageView = UIImageView()
        newImageView.backgroundColor = .black
        newImageView.frame = UIScreen.main.bounds
        newImageView.contentMode = .scaleAspectFit
        newImageView.image = image
        newImageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissFullscreenImage))
        newImageView.addGestureRecognizer(tap)
        self.presenterController.view.addSubview(newImageView)
        self.presenterController.navigationController?.isNavigationBarHidden = true
        UIApplication.shared.isStatusBarHidden = true
    }

    @objc private func dismissFullscreenImage(_ sender: UITapGestureRecognizer) {
        self.presenterController.navigationController?.isNavigationBarHidden = false
        sender.view?.removeFromSuperview()
        UIApplication.shared.isStatusBarHidden = false
    }
}
