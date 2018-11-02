/*
 * main.swift
 * ManualTest
 *
 * Created by François Lamboley on 2018/11/2.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation

import URLRequestOperation



let q = OperationQueue()
let request = URLRequest(url: URL(string: "https://frostland.fr")!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 0.1)
let operation = URLRequestOperation(request: request)
q.addOperation(operation)

dispatchMain()
