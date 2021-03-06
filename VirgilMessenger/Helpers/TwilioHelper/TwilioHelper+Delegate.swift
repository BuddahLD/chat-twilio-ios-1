//
//  TwilioHelper+Delegate.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit
import CoreData
import Foundation
import TwilioChatClient

extension TwilioHelper: TwilioChatClientDelegate {
    enum Notifications: String {
        case ConnectionStateUpdated = "TwilioHelper.Notifications.ConnectionStateUpdated"
        case MessageAdded = "TwilioHelper.Notifications.MessageAdded"
        case MessageAddedToSelectedChannel = "TwilioHelper.Notifications.MessageAddedToSelectedChannel"
        case ChannelAdded = "TwilioHelper.Notifications.ChannelAdded"
    }

    enum NotificationKeys: String {
        case NewState = "TwilioHelper.NotificationKeys.NewState"
        case Message = "TwilioHelper.NotificationKeys.Message"
        case Channel = "TwilioHelper.NotificationKeys.Channel"
    }

    enum ConnectionState: String {
        case unknown = "unknown"
        case disconnected = "disconnected"
        case connected = "connected"
        case connecting = "connecting"
        case denied = "denied"
        case error = "error"

        init(state: TCHClientConnectionState) {
            switch state {
            case .unknown: self = .unknown
            case .disconnected: self = .disconnected
            case .connected: self = .connected
            case .connecting: self = .connecting
            case .denied: self = .denied
            case .error: self = .error
            }
        }
    }

    func chatClient(_ client: TwilioChatClient, connectionStateUpdated state: TCHClientConnectionState) {
        let connectionState = ConnectionState(state: state)

        let stateStr = connectionState.rawValue
        Log.debug("\(stateStr)")

        NotificationCenter.default.post(
            name: Notification.Name(rawValue: TwilioHelper.Notifications.ConnectionStateUpdated.rawValue),
            object: self,
            userInfo: [
                TwilioHelper.NotificationKeys.NewState.rawValue: connectionState
            ])
    }

    func chatClient(_ client: TwilioChatClient, channelAdded channel: TCHChannel) {
        Log.debug("Channel added")
        if channel.status == TCHChannelStatus.invited {
            channel.join { channelResult in
                if channelResult.isSuccessful() {
                    Log.debug("Successfully accepted invite.")
                    let identity = self.getCompanion(ofChannel: channel)
                    Log.debug("identity: \(identity)")
                    VirgilHelper.sharedInstance.getCard(withIdentity: identity) { card, error in
                        guard let card = card, error == nil else {
                            Log.error("failed to add new channel card")
                            return
                        }
                        _ = CoreDataHelper.sharedInstance.createChannel(withName: identity, card: card.exportData())
                        Log.debug("new card added")
                        NotificationCenter.default.post(
                            name: Notification.Name(rawValue: TwilioHelper.Notifications.ChannelAdded.rawValue),
                            object: self,
                            userInfo: [:])
                    }
                } else {
                    Log.error("Failed to accept invite.")
                }
            }
        }
    }

    func chatClient(_ client: TwilioChatClient, channelDeleted channel: TCHChannel) {
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: TwilioHelper.Notifications.ChannelAdded.rawValue),
            object: self,
            userInfo: [:])
    }

    func chatClient(_ client: TwilioChatClient, channel: TCHChannel, messageAdded message: TCHMessage) {
        Log.debug("message added")
        guard self.currentChannel != nil else {
            self.processMessage(channel: channel, message: message)
            return
        }
        if getCompanion(ofChannel: channel) == getCompanion(ofChannel: self.currentChannel) {
            Log.debug("it's from selected channel")
            if message.author != self.username {
                Log.debug("author is not me")
                NotificationCenter.default.post(
                    name: Notification.Name(rawValue: TwilioHelper.Notifications.MessageAddedToSelectedChannel.rawValue),
                    object: self,
                    userInfo: [
                        TwilioHelper.NotificationKeys.Message.rawValue: message
                    ])
            }
        } else {
            self.processMessage(channel: channel, message: message)
        }
    }

    private func processMessage(channel: TCHChannel, message: TCHMessage) {
        guard let messageDate = message.dateUpdatedAsDate else {
            Log.error("got corrupted message")
            return
        }
        guard let coreDataChannel = CoreDataHelper.sharedInstance.getChannel(withName: self.getCompanion(ofChannel: channel)),
              let cardString = coreDataChannel.card else {
            Log.error("can't get core data channel")
            return
        }

        if message.hasMedia() {
            self.getMedia(from: message) { encryptedData in
                guard let encryptedData = encryptedData,
                    let encryptedString = String(data: encryptedData, encoding: .utf8),
                    let decryptedString = VirgilHelper.sharedInstance.decryptPFS(cardString: cardString, encrypted: encryptedString),
                    let decryptedData = Data(base64Encoded: decryptedString) else {
                        Log.error("decryption process of media message failed")
                        return
                }
               if (coreDataChannel.message?.count == 0 || (Int(truncating: message.index ?? 0) >= (coreDataChannel.message?.count ?? 0))) {
                    CoreDataHelper.sharedInstance.createMediaMessage(forChannel: coreDataChannel, withData: decryptedData,
                                                                     isIncoming: true, date: messageDate)
                }
            }
        } else if let messageBody = message.body {
            guard let decryptedMessageBody = VirgilHelper.sharedInstance.decryptPFS(cardString: cardString, encrypted: messageBody) else {
                return
            }

            coreDataChannel.lastMessagesBody = decryptedMessageBody
            coreDataChannel.lastMessagesDate = messageDate

            if (coreDataChannel.message?.count == 0 || (Int(truncating: message.index ?? 0) >= (coreDataChannel.message?.count ?? 0))) {
                CoreDataHelper.sharedInstance.createTextMessage(forChannel: coreDataChannel, withBody: decryptedMessageBody, isIncoming: true, date: messageDate)
            }
            Log.debug("Receiving " + decryptedMessageBody)
        }
        NotificationCenter.default.post(
            name: Notification.Name(rawValue: TwilioHelper.Notifications.MessageAdded.rawValue),
            object: self,
            userInfo: [
                TwilioHelper.NotificationKeys.Message.rawValue: message
            ])
    }
}
