//
//  DemoDataSource.swift
//  CollectionDemo
//
//  Created by Антон Королев on 24.05.2026.
//

import Foundation

struct Message {
    let title: String
    let isMy: Bool
    let date: Date
    init(title: String, isMy: Bool = true, date: Date = Date()) {
        self.title = title
        self.isMy = isMy
        self.date = date
    }
}

let demoMessages: [Message] = [
    Message(title: "Привет! Как дела?", isMy: false, date: Date(timeIntervalSinceNow: -86400 * 2)),
    Message(title: "Привет, всё отлично! А у тебя?", date: Date(timeIntervalSinceNow: -86400 * 2 + 60)),
    Message(title: "Тоже норм, чем занят?", isMy: false, date: Date(timeIntervalSinceNow: -86400 * 2 + 120)),
    Message(title: "Да вот пилю новый проект на Swift", date: Date(timeIntervalSinceNow: -86400 * 2 + 180)),
    Message(title: "О, круто! Что именно делаешь?", isMy: false, date: Date(timeIntervalSinceNow: -86400 * 2 + 240)),
    Message(title: "Мессенджер на UICollectionView", date: Date(timeIntervalSinceNow: -86400 * 2 + 300)),
    Message(title: "Звучит интересно 🚀", isMy: false, date: Date(timeIntervalSinceNow: -86400 + 3600)),
    Message(title: "Ага, разбираюсь с compositional layout", date: Date(timeIntervalSinceNow: -86400 + 3700)),
    Message(title: "А кстати ты видел новую WWDC?", isMy: false, date: Date(timeIntervalSinceNow: -86400 + 7200)),
    Message(title: "Не успел ещё, что там интересного?", date: Date(timeIntervalSinceNow: -86400 + 7300)),
    Message(title: "Много всего по SwiftUI и Swift 6", isMy: false, date: Date(timeIntervalSinceNow: -86400 + 7400)),
    Message(title: "О, надо глянуть на выходных", date: Date(timeIntervalSinceNow: -86400 + 7500)),
    Message(title: "Особенно зашёл новый Observation framework", isMy: false, date: Date(timeIntervalSinceNow: -86400 + 7600)),
    Message(title: "Да, видел доку, выглядит мощно", date: Date(timeIntervalSinceNow: -86400 + 7700)),
    Message(title: "Пойдём кофе попьём?", isMy: false, date: Date(timeIntervalSinceNow: -3600 * 5)),
    Message(title: "Давай, через 20 минут?", date: Date(timeIntervalSinceNow: -3600 * 5 + 120)),
    Message(title: "Окей, в нашем обычном месте", isMy: false, date: Date(timeIntervalSinceNow: -3600 * 5 + 180)),
    Message(title: "Договорились ☕️", date: Date(timeIntervalSinceNow: -3600 * 5 + 240)),
    Message(title: "Я уже на месте", isMy: false, date: Date(timeIntervalSinceNow: -3600 * 4)),
    Message(title: "Бегу, через 5 минут буду", date: Date(timeIntervalSinceNow: -3600 * 4 + 60)),
    Message(title: "Ок, заказал тебе латте", isMy: false, date: Date(timeIntervalSinceNow: -3600 * 4 + 120)),
    Message(title: "Спасибо, ты лучший!", date: Date(timeIntervalSinceNow: -3600 * 4 + 180)),
    Message(title: "Да ладно тебе 😄", isMy: false, date: Date(timeIntervalSinceNow: -3600 * 4 + 240)),
]
