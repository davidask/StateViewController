//
//  Comment.swift
//  StateViewControllerExample
//
//  Created by David Ask on 2018-08-16.
//  Copyright © 2018 Formbound. All rights reserved.
//

import Foundation

struct Comment: Decodable {
    let id: Int
    let name: String
    let email: String
    let body: String

    static func loadComments(_ completion: @escaping (Error?, [Comment]?) -> Void) {

        let url = URL(string: "https://jsonplaceholder.typicode.com/comments")!

        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(error, nil)
                return
            }

            guard let data = data else {
                completion(nil, [])
                return
            }

            do {
                completion(nil, try JSONDecoder().decode([Comment].self, from: data))
            } catch {
                completion(error, nil)
            }
        }

        task.resume()
    }
}

extension Comment: Equatable {
    static func == (lhs: Comment, rhs: Comment) -> Bool {
        return lhs.id == rhs.id
    }
}
