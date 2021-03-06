//
//  ChatListViewController.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/18/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import Foundation
import UIKit
import PKHUD

class ChatListViewController: ViewController {
    @IBOutlet weak var noChatsView: UIView!
    @IBOutlet weak var tableView: UITableView!

    static let name = "ChatList"

    override func viewDidLoad() {
        super.viewDidLoad()

        self.updateLastMessages()

        self.tableView.register(UINib(nibName: ChatListCell.name, bundle: Bundle.main),
                                forCellReuseIdentifier: ChatListCell.name)
        self.tableView.rowHeight = 94
        self.tableView.tableFooterView = UIView(frame: .zero)
        self.tableView.backgroundColor = UIColor(rgb: 0x2B303B)
        self.tableView.dataSource = self

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ChatListViewController.reloadTableView(notification:)),
                                               name: Notification.Name(rawValue: TwilioHelper.Notifications.ChannelAdded.rawValue),
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ChatListViewController.reloadTableView(notification:)),
                                               name: Notification.Name(rawValue: TwilioHelper.Notifications.MessageAdded.rawValue),
                                               object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        TwilioHelper.sharedInstance.deselectChannel()
        VirgilHelper.sharedInstance.setChannelCard(nil)
        noChatsView.isHidden = TwilioHelper.sharedInstance.channels.subscribedChannels().isEmpty ? false : true
        self.tableView.reloadData()
    }

    @objc private func reloadTableView(notification: Notification) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.noChatsView.isHidden = true
        }
    }

    private func updateLastMessages() {
        let channels = TwilioHelper.sharedInstance.channels.subscribedChannels()

        for i in 0..<channels.count {
            let channel = channels[i]
            let channelName = TwilioHelper.sharedInstance.getCompanion(ofChannel: channel)
            if let channelCore = CoreDataHelper.sharedInstance.getChannel(withName: channelName),
                let messages = channel.messages,
                let messagesCore = channelCore.message {

                CoreDataHelper.sharedInstance.setLastMessage(for: channelCore)

                TwilioHelper.sharedInstance.decryptFirstMessage(of: messages, channel: channelCore, saved: messagesCore.count) { message, decryptedBody, decryptedMedia, messageDate in
                    guard let message = message,
                        let messageDate = messageDate else {
                            return
                    }
                    TwilioHelper.sharedInstance.setLastMessage(of: messages, channel: channelCore) {
                        self.tableView.reloadData()
                    }

                    if (messagesCore.count == 0 || (Int(truncating: message.index ?? 0) >= (messagesCore.count))) {
                        if let decryptedBody = decryptedBody {
                            CoreDataHelper.sharedInstance.createTextMessage(forChannel: channelCore, withBody: decryptedBody,
                                                                            isIncoming: true, date: messageDate)
                        } else if let decryptedMedia = decryptedMedia {
                            CoreDataHelper.sharedInstance.createMediaMessage(forChannel: channelCore, withData: decryptedMedia, isIncoming: true, date: messageDate)
                        }
                    }
                }
            } else {
                Log.error("updating last messages failed")
            }
        }
    }

    @IBAction func noChatsTap(_ sender: Any) {
        self.didTapAdd(self)
    }

    @IBAction func didTapAdd(_ sender: Any) {
        guard currentReachabilityStatus != .notReachable else {
            let controller = UIAlertController(title: self.title, message: "Please check your network connection", preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(controller, animated: true)

            return
        }

        let alertController = UIAlertController(title: "Add", message: "Enter username", preferredStyle: .alert)

        alertController.addTextField(configurationHandler: {
            $0.placeholder = "Username"
            $0.delegate = self
            $0.keyboardAppearance = UIKeyboardAppearance.dark
        })

        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            guard let username = alertController.textFields?.first?.text else {
                return
            }
            self.addChat(withUsername: username)
        }))

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in }))

        self.present(alertController, animated: true)
    }

    private func addChat(withUsername username: String) {
        let username = username.lowercased()

        guard username != TwilioHelper.sharedInstance.username else {
            self.alert(withTitle: "You need to communicate with other people :)")
            return
        }

        if (TwilioHelper.sharedInstance.channels.subscribedChannels().contains {
            ($0.attributes()?.values.contains { value -> Bool in
                value as! String == username
            }) ?? false
        }) {
            self.alert(withTitle: "You already have this channel")
        } else {
            HUD.show(.progress)
            TwilioHelper.sharedInstance.createChannel(withUsername: username) { error in
                HUD.flash(.success)
                if error == nil {
                    self.noChatsView.isHidden = true
                    self.tableView.reloadData()
                    HUD.flash(.success)
                } else {
                    HUD.flash(.error)
                }

            }
        }
    }

    private func alert(withTitle: String) {
        let alert = UIAlertController(title: title, message: withTitle, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

        self.present(alert, animated: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension ChatListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatListCell.name) as! ChatListCell

        guard let account = CoreDataHelper.sharedInstance.currentAccount,
              let channels = account.channel else {
                Log.error("Can't form row: Core Data account or channels corrupted")
                return cell
        }
        let count = channels.count

        cell.tag = count - indexPath.row - 1
        cell.delegate = self

        guard let channel = channels[count - indexPath.row - 1] as? Channel else {
            Log.error("Can't form row: Core Data channel corrupted")
            return cell
        }
        cell.usernameLabel.text = channel.name
        cell.letterLabel.text = channel.letter
        cell.avatarView.gradientLayer.colors = [channel.colorPair.first, channel.colorPair.second]
        cell.avatarView.gradientLayer.gradient = GradientPoint.bottomLeftTopRight.draw()

        cell.lastMessageLabel.text = channel.lastMessagesBody
        cell.lastMessageDateLabel.text = channel.lastMessagesDate != nil ? calcDateString(messageDate: channel.lastMessagesDate!) : ""

        return cell
    }

    private func calcDateString(messageDate: Date) -> String {

        let dateFormatter = DateFormatter()
        if messageDate.minutes(from: Date()) < 2 {
            return "now"
        } else if messageDate.days(from: Date()) < 1 {
            dateFormatter.dateStyle = DateFormatter.Style.none
            dateFormatter.timeStyle = DateFormatter.Style.short
        } else {
            dateFormatter.dateStyle = DateFormatter.Style.short
            dateFormatter.timeStyle = DateFormatter.Style.none
        }

        let messageDateString = dateFormatter.string(from: messageDate)

        return messageDateString
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let account = CoreDataHelper.sharedInstance.currentAccount,
              let channels = account.channel else {
                Log.error("Can't form row: Core Data account or channels corrupted")
                return 0
        }
        return channels.count
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = UIColor(rgb: 0x2B303B)
    }

//     func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
//         if editingStyle == .delete {
//             CoreDataHelper.sharedInstance.deleteChannel(withName: TwilioHelper.sharedInstance.getCompanion(ofChannel: indexPath.row))
//             TwilioHelper.sharedInstance.destroyChannel(indexPath.row) {
//             self.tableView.reloadData()
//             }
//         }
//     }
}

extension ChatListViewController: CellTapDelegate {
    func didTapOn(_ cell: UITableViewCell) {
        if let username = (cell as! ChatListCell).usernameLabel.text {
            TwilioHelper.sharedInstance.setChannel(withUsername: (username))

            guard CoreDataHelper.sharedInstance.loadChannel(withName: username),
                let channel = CoreDataHelper.sharedInstance.currentChannel,
                let exportedCard = channel.card
                else {
                    Log.error("Channel do not exist in Core Data")
                    return
            }

            VirgilHelper.sharedInstance.setChannelCard(exportedCard)

            self.performSegue(withIdentifier: "goToChat", sender: self)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if let chatController = segue.destination as? ChatViewController {
            let pageSize = ChatConstants.chatPageSize

            let dataSource = DataSource(pageSize: pageSize)
            chatController.title = TwilioHelper.sharedInstance.getCompanion(ofChannel: TwilioHelper.sharedInstance.currentChannel)
            chatController.dataSource = dataSource
            chatController.messageSender = dataSource.messageSender
        }
    }
}

extension ChatListViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        if string.rangeOfCharacter(from: ChatConstants.characterSet.inverted) != nil {
            Log.debug("string contains special characters")
            return false
        }
        let newLength = text.count + string.count - range.length
        return newLength <= ChatConstants.limitLength
    }
}
