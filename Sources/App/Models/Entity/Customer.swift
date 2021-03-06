//
//  Customer.swift
//  AppServer
//
//  Created by Anton Poltoratskyi on 29.10.16.
//
//


import Foundation
import Vapor
import Auth
import BCrypt
import Fluent
import HTTP

final class Customer: Model, User {
    
    var id: Node?
    var name: String
    var login: String
    var hash: String
    var token: String = ""
    
    var exists: Bool = false
    
    init(name: String, login: String, password: String) {
        self.name = name
        self.login = login
        self.hash = BCrypt.hash(password: password)
    }
    
    
    //MARK: - NodeConvertible
    
    init(node: Node, in context: Context) throws {
        id = try node.extract("_id")
        name = try node.extract("name")
        login = try node.extract("login")
        hash = try node.extract("hash")
        token = try node.extract("access_token")
    }
    
    func makeNode(context: Context) throws -> Node {
        return try Node(node: [
            "_id": id,
            "name": name,
            "login": login,
            "hash": hash,
            "access_token": token
            ])
    }
}


//MARK: - Public Response
extension Customer: PublicResponseRepresentable {
    
    func publicResponseNode() throws -> Node {
        
        return try Node(node: [
            "_id": id,
            "name": name,
            "login": login,
            "access_token": token
            ])
    }
    
    func infoResponseNode() throws -> Node {
        
        return try Node(node: [
            "_id": id,
            "name": name,
            "login": login
            ])
    }
}


//MARK: - Preparation
extension Customer {
    
    static func prepare(_ database: Database) throws {
        try database.create("customers") { users in
            users.id("_id")
            users.string("name")
            users.string("login")
            users.string("hash")
            users.string("access_token")
        }
    }
    
    static func revert(_ database: Database) throws {
        try database.delete("customers")
    }
}


//MARK: - DB Relations
extension Customer {
    
    func orders() -> Children<Order> {
        return children("customer_id", Order.self)
    }
}


//MARK: - Auth.User
extension Customer: Auth.User {
    
    static func authenticate(credentials: Credentials) throws -> Auth.User {
        
        var customer: Customer?
        
        switch credentials {
            
        case let id as Identifier:
            customer = try Customer.find(id.id)
            
        case let accessToken as AccessToken:
            customer = try Customer.query().filter("access_token", accessToken.string).first()
            
        case let apiKey as APIKey:
            do {
                if let tempUser = try Customer.query().filter("login", apiKey.id).first() {
                    
                    if try BCrypt.verify(password: apiKey.secret, matchesHash: tempUser.hash) {
                        customer = tempUser
                    }
                }
            }
        default:
            throw Abort.custom(status: .badRequest, message: "Invalid credentials")
        }
        
        guard let resultCustomer = customer else {
            throw Abort.custom(status: .badRequest, message: "Invalid credentials")
        }
        return resultCustomer
    }
    
    static func register(credentials: Credentials) throws -> Auth.User {
        throw Abort.custom(status: .badRequest, message: "Registration not supported")
    }
}


//MARK: - Request
extension Request {
    func customer() throws -> Customer {
        return try auth.user() as! Customer
    }
}


