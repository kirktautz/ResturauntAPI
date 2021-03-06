//
//  Resturaunt.swift
//  ResturauntAPI
//
//  Created by Kirk Tautz on 7/4/17.
//
//

import Foundation
import SwiftyJSON
import LoggerAPI
import MongoKitten
import Credentials
import Cryptor
import KTD_Kitura_CredentialsJWT

public enum APICollectionError: Error {
    case parseError
    case authError
    case databaseError
}

public class Resturaunt: ResturauntAPI {
    
    private let mongoUrl = "mongodb://localhost:27017"
    public let jwtCredentials = Credentials()
    
    // initialize and setup db
    public init() {
//        setupAuth()
        setupDB()
    }
    
    // setup auth
    private func setupAuth() {
        
        guard let file = retrieveSecrets(), let secret = file["JWT_Secret"] else {
            Log.error("Could not get secret")
            return
        }
        
        let jwtCreds =  KTDCredentialsJWT(secretKey: secret)
        
        self.jwtCredentials.register(plugin: jwtCreds)
        
        
    }
    
    private func retrieveSecrets() -> [String: String]? {
        
        let plistPath = FileManager().currentDirectoryPath + "/SecretsList.plist"
        var format = PropertyListSerialization.PropertyListFormat.binary
        let data = FileManager().contents(atPath: plistPath)
        
        guard let plist = try? PropertyListSerialization.propertyList(from: data!, options: .mutableContainersAndLeaves, format: &format)  else {
            
            Log.error("Could not get secrets file")
            return nil
        }
        
        guard let plistData = plist as? [String: String] else {
            Log.error("Could not convert plist to dictionary")
            return nil
        }
        
        return plistData
    }
    
    // Check connection to MongoDB is successful
    private func setupDB() {
        do {
            _ = try connectToDB()
            Log.info("Successfully setup database")
        } catch {
            Log.error("Could not setup database")
        }
    }
    
    // Connect to MongoDB to use database
    private func connectToDB() throws -> Database? {
        Log.info("Establishing connection to MongoDB database")
        
        do {
            
            let server = try Server(mongoUrl)
            let db = server["dev"]
            
            Log.info("Connected to database")
            return db
        } catch {
            Log.error("Could not connect to the database")
            return nil
        }
    }
    
    // MARK: - Menu Items
    
    // get all menu items
    public func getMenuItems(completion: @escaping ([MenuItem]?, Error?) -> Void) {
        
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(nil, APICollectionError.databaseError)
            
            return
        }
        
        let collection = db!["menu_items"]
        
        do {
            let recievedItems = try collection.find()
            
            var itemsArr = [MenuItem]()
            for item in recievedItems {
                if let id = String(item["_id"]), let name = String(item["itemname"]), let price = Double(item["itemprice"]), let type = String(item["itemtype"]), let subType = String(item["itemsubtype"]), let imgUrl = String(item["imgurl"]), let date = String(item["date"]) {
                    
                    let newItem = MenuItem(id: id, name: name, price: price, type: type, subType: subType, imgUrl: imgUrl, date: date)
                    
                    itemsArr.append(newItem)
                } else {
                    completion(nil, APICollectionError.parseError)
                    Log.warning("Could not get values from document")
                }
                
            }
            
            completion(itemsArr, nil)
            
        } catch {
            Log.error("Could not perform db fetch")
            completion(nil, APICollectionError.databaseError)
        }
        
        
    }
    
    // Get specific menu item
    public func getMenuItem(id: String, completion: @escaping (MenuItem?, Error?) -> Void){
        
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(nil, APICollectionError.databaseError)
            
            return
        }
        
        let collection = db!["menu_items"]
        
        do {
            
            let objectId = try ObjectId(id)
            let retrievedMenuItem = try collection.findOne("_id" == objectId)
            
            if let retrievedMenuItem = retrievedMenuItem {
                if let name = String(retrievedMenuItem["itemname"]), let price = Double(retrievedMenuItem["itemprice"]), let type = String(retrievedMenuItem["itemtype"]), let subType = String(retrievedMenuItem["itemsubtype"]), let imgUrl = String(retrievedMenuItem["imgurl"]), let date = String(retrievedMenuItem["date"]) {
                    
                    let menuItem = MenuItem(id: id, name: name, price: price, type: type, subType: subType, imgUrl: imgUrl, date: date)
                    completion(menuItem, nil)
                } else {
                    completion(nil, APICollectionError.parseError)
                }
            }
        } catch {
            completion(nil, APICollectionError.databaseError)
        }
    }
    
    // add new menu item
    public func addMenuItem(itemType: String, itemSubType: String, itemName: String, itemPrice: Double, imgUrl: String, completion: @escaping (MenuItem?, Error?) -> Void) {
        
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(nil, APICollectionError.databaseError)
            
            return
        }
        
        let collection = db!["menu_items"]
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        let date = formatter.string(from: Date())
        
        let document: Document = [
            "itemtype" : itemType,
            "itemsubtype" : itemSubType,
            "itemname" : itemName,
            "itemprice" : itemPrice,
            "imgurl" : imgUrl,
            "date" : date
        ]
        
        do {
            let id = try collection.insert(document)
            
            if let id = String(id) {
                let menuItem = MenuItem(id: id, name: itemName, price: itemPrice, type: itemType, subType: itemSubType, imgUrl: imgUrl, date: date)
                
                completion(menuItem, nil)
                Log.info("Successfully added document")
            } else {
                Log.error("Did not retrieve ID")
            }
        } catch {
            Log.warning("Could not add document")
        }
        
    }
    
    // edit an existing menu item. If values are nil, the saved data will be used
    public func editMenuItem(id: String, itemType: String?, itemSubType: String?, itemName: String?, itemPrice: Double?, imgUrl: String?, completion: @escaping (MenuItem?, Error?) -> Void) {
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(nil, APICollectionError.databaseError)
            
            return
        }
        
        let collection = db!["menu_items"]
        
        do {
            
            let objectId = try ObjectId(id)
            let query: Query = "_id" == objectId
            
            if let result = try collection.findOne(query) {
                guard let dbName = String(result["itemname"]), let dbPrice = Double(result["itemprice"]), let dbType = String(result["itemtype"]), let dbSubType = String(result["itemsubtype"]), let dbImgUrl = String(result["imgurl"]) else {
                    
                    Log.error("Document data is incomplete")
                    completion(nil, APICollectionError.databaseError)
                    return
                }
                
                let name = itemName ?? dbName
                let type = itemType ?? dbType
                let subType = itemSubType ?? dbSubType
                let price = itemPrice ?? dbPrice
                let img = imgUrl ?? dbImgUrl
                
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                let date = formatter.string(from: Date())
                
                let updatedDocumet: Document = [
                    "itemtype" : type,
                    "itemsubtype" : subType,
                    "itemname" : name,
                    "itemprice" : price,
                    "imgurl" : img,
                    "date" : date
                ]
                
                try collection.update("_id" == objectId, to: updatedDocumet)
                let menuItem = MenuItem(id: id, name: name, price: price, type: type, subType: subType, imgUrl: img, date: date)
                completion(menuItem, nil)
                
            } else {
                Log.error("Could not unwrap result")
                completion(nil, APICollectionError.databaseError)
            }
            
        } catch {
            Log.error("Could not find document")
        }
    }
    
    // delete menu item
    public func deleteMenuItem(id: String, completion: @escaping (Error?) -> Void) {
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(APICollectionError.databaseError)
            
            return
        }
        
        let collection = db!["menu_items"]
        
        do {
            let objectId = try ObjectId(id)
            try collection.remove("_id" == objectId)
            completion(nil)
        } catch {
            Log.warning("Could not remove object")
            completion(APICollectionError.databaseError)
        }
        
    }
    
    // Delete all items
    public func clearMenuItems(completion: (Error?) -> Void) {
        
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(APICollectionError.databaseError)
            
            return
        }
        
        let collection = db!["menu_items"]
        do {
            let docs = try collection.find()
            
            for doc in docs {
                try collection.remove("_id" == doc["_id"])
            }
            
            Log.info("Cleared all documents")
            completion(nil)
        } catch {
            Log.warning("Could not remove documents")
            completion(APICollectionError.databaseError)
        }
    }
    
    // get items by type
    public func getItemsByType(type: String, subType: String?, completion: @escaping ([MenuItem]?, Error?) -> Void){
        
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(nil, APICollectionError.databaseError)
            
            return
        }
        
        let collection = db!["menu_items"]
        
        let query: Query
        
        if subType != nil {
            query = "itemsubtype" == subType
        } else {
            query = "itemtype" == type
        }
        
        do {
            let retResults = try collection.find(query)
            
            var itemsArr = [MenuItem]()
            for item in retResults {
                if let id = String(item["_id"]), let name = String(item["itemname"]), let price = Double(item["itemprice"]), let type = String(item["itemtype"]), let subType = String(item["itemsubtype"]), let imgUrl = String(item["imgurl"]), let date = String(item["date"]) {
                    
                    let newItem = MenuItem(id: id, name: name, price: price, type: type, subType: subType, imgUrl: imgUrl, date: date)
                    
                    itemsArr.append(newItem)
                } else {
                    completion(nil, APICollectionError.parseError)
                    Log.warning("Could not get values from document")
                }
                
            }
            
            completion(itemsArr, nil)
            
        } catch {
            
        }
    }
    
    // Count of all menu items
    public func countMenuItems(completion: @escaping (Int?, Error?) ->Void) {
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(nil, APICollectionError.databaseError)
            
            return
        }
        
        let collection = db!["menu_items"]
        
        do {
            let results = try collection.find()
            let count = try results.count()
            
            Log.info("query return \(count) items")
            completion(count, nil)
        } catch {
            Log.error("Could not get count")
            completion(nil, APICollectionError.databaseError)
            
        }
    }
    
    // MARK: Events
    
    // get all events
    public func getEventItems(completion: @escaping ([EventItem]?, Error?) -> Void) {
        
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            
            return
        }
        
        let collection = db!["event_items"]
        
        do {
            
            let retrievedItems = try collection.find()
            
            var returnedEvents = [EventItem]()
            for item in retrievedItems {
                if let eventName = String(item["eventname"]), let eventDate = String(item["eventdate"]), let eventId = String(item["_id"]), let date = String(item["date"]), let eventDescription = String(item["eventdescription"]) {
                    
                    let newEvent = EventItem(id: eventId, name: eventName, eventDate: eventDate, date: date, eventDescription: eventDescription)
                    returnedEvents.append(newEvent)
                } else {
                    completion(nil, APICollectionError.parseError)
                    Log.error("Could not get all items from database")
                }
            }
            Log.info("returning events")
            completion(returnedEvents, nil)
            
        } catch {
            Log.error("Could not connect to database")
            completion(nil, APICollectionError.databaseError)
        }
        
    }
    
    // get specific event item
    public func getEventItem(id: String, completion: @escaping (EventItem?, Error?) ->Void) {
        
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(nil, APICollectionError.databaseError)
            return
        }
        
        let collection = db!["event_items"]
        
        do {
            
            let objectId = try ObjectId(id)
            let query: Query = "_id" == objectId
            let result = try collection.findOne(query)
            
            if let result = result {
                if let eventName = String(result["eventname"]), let eventDate = String(result["eventdate"]), let date = String(result["date"]), let eventDescription = String(result["eventdescription"]) {
                    
                    let newEvent = EventItem(id: id, name: eventName, eventDate: eventDate, date: date, eventDescription: eventDescription)
                    
                    completion(newEvent, nil)
                } else {
                    Log.error("Could not get event fields")
                    completion(nil, APICollectionError.parseError)
                }
                
            } else {
                Log.error("Could not find any events")
                completion(nil, APICollectionError.databaseError)
            }
            
        } catch {
            
        }
        
        
    }
    
    // add event item
    public func addEvent(eventName: String, eventDate: String, eventDescription: String, completion: @escaping (EventItem?, Error?) -> Void) {
        
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(nil, APICollectionError.databaseError)
            return
        }
        
        guard eventName != "", eventDate != "", eventDescription != "" else {
            Log.error("Required fields not filled out")
            completion(nil, APICollectionError.parseError)
            return
        }
        
        let collection = db!["event_items"]
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        let formattedDate = formatter.string(from: Date())
        
        let eventDoc: Document = [
            "eventname": eventName,
            "eventdate" : eventDate,
            "date": formattedDate,
            "eventdescription": eventDescription
        ]
        
        do {
            let eventId = try collection.insert(eventDoc)
            
            guard let stringId = String(eventId) else {
                Log.error("Could not convert objectId")
                completion(nil, APICollectionError.parseError)
                return
            }
            
            let newEvent = EventItem(id: stringId, name: eventName, eventDate: eventDate, date: formattedDate, eventDescription: eventDescription)
            
            completion(newEvent, nil)
            
        } catch {
            Log.error("Could not create event")
            completion(nil, APICollectionError.databaseError)
        }
        
    }
    
    // edit event item
    public func editEvent(id: String, eventName: String?, eventDate: String?, eventDescription: String?, completion: @escaping (EventItem?, Error?) -> Void) {
        
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(nil, APICollectionError.databaseError)
            return
        }
        
        let collection = db!["event_items"]
        
        do {
            let objectId = try ObjectId(id)
            let query: Query = "_id" == objectId
            let result = try collection.findOne(query)
            
            if let result = result {
                
                
                guard let dbName = String(result["eventname"]), let dbEvDate = String(result["eventdate"]), let dbDescription = String(result["eventdescription"]) else {
                    return
                }
                
                let name = eventName ?? dbName
                let evDate = eventDate ?? dbEvDate
                let desc = eventDescription ?? dbDescription
                
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                let formattedDate = formatter.string(from: Date())
                
                let newDoc:Document = [
                    "eventname": name,
                    "eventdate": evDate,
                    "date": formattedDate,
                    "eventdescription": desc
                ]
                
                try collection.update("_id" == objectId, to: newDoc)
                
                let updateEvent = EventItem(id: id, name: name, eventDate: evDate, date: formattedDate, eventDescription: desc)
                completion(updateEvent, nil)
                
            } else {
                completion(nil, APICollectionError.databaseError)
                Log.error("Event not found")
            }
            
        } catch {
            Log.error("Communicatiosn error")
        }
        
    }
    
    // delete event
    public func deleteEvent(id: String, completion: @escaping (Error?) -> Void) {
        
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(APICollectionError.databaseError)
            return
        }
        
        let collection = db!["event_items"]
        
        do {
            let objectId = try ObjectId(id)
            try collection.remove("_id" == objectId)
            completion(nil)
            
        } catch {
            completion(APICollectionError.databaseError)
        }
    }
    
    // count all events
    public func countEventItems(completion: @escaping (Int?, Error?) -> Void) {
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(nil, APICollectionError.databaseError)
            return
        }
        
        let collection = db!["event_items"]
        
        do{
            let results = try collection.findOne()
            if let count = results?.count {
                completion(count, nil)
                
            } else {
                Log.error("Could not get event items")
                completion(nil, APICollectionError.databaseError)
            }
            
        } catch {
            Log.error("Could not get event items")
            completion(nil, APICollectionError.databaseError)
        }
    }
    
    // clear all events
    public func clearEventItems(completion: (Error?) -> Void) {
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(APICollectionError.databaseError)
            
            return
        }
        
        let collection = db!["event_items"]
        do {
            let docs = try collection.find()
            
            for doc in docs {
                try collection.remove("_id" == doc["_id"])
            }
            
            Log.info("Cleared all documents")
            completion(nil)
        } catch {
            Log.warning("Could not remove documents")
            completion(APICollectionError.databaseError)
        }
        
    }
    
    // MARK: - Reviews
    // get all reviews for item
    public func getAllReviewsForItem(parentId: String, completion: @escaping ([ReviewItem]?, Error?) -> Void) {
        
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(nil ,APICollectionError.databaseError)
            return
        }
        
        let collection = db!["reviews"]
        
        let query: Query = ["parentid" : parentId]
        let sort: Sort = ["date": .descending]
        do {
            
            let results = try collection.find(query, sortedBy: sort)
            
            var reviewItems = [ReviewItem]()
            
            for result in results {
                if let reviewId = String(result["_id"]), let reviewTitle = String(result["reviewtitle"]), let reviewContent = String(result["reviewcontent"]), let postDate = Date(result["date"]), let rating = Int(result["rating"]), let userId = String(result["userid"]) {
                    
                    let newReview = ReviewItem(reviewId: reviewId, userId: userId, reviewTitle: reviewTitle, reviewContent: reviewContent, postDate: postDate, rating: rating, parentItem: parentId)
                    
                    reviewItems.append(newReview)
                } else {
                    completion(nil, APICollectionError.parseError)
                    Log.error("Could not get review details")
                }
            }
            
            completion(reviewItems, nil)
            
        } catch {
            completion(nil, APICollectionError.databaseError)
            Log.error("Could not find reviews")
        }
    }
    
    // add review
    public func addReview(parentId: String, userId: String, reviewTitle: String, reviewContent: String, rating: Int, completion: @escaping (ReviewItem?, Error?) -> Void) {
        
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(nil ,APICollectionError.databaseError)
            return
        }
        
        let collection = db!["reviews"]
        
        let date = Date()
        
        let doc: Document = [
            "parentid": parentId,
            "userid": userId,
            "reviewtitle" : reviewTitle,
            "reviewcontent": reviewContent,
            "rating": rating,
            "date": date
        ]
        
        do {
            
            let returnedId = try collection.insert(doc)
            
            guard let reviewId = String(returnedId) else {
                Log.error("Could not get id")
                completion(nil, APICollectionError.parseError)
                return
            }
            
            let newReview = ReviewItem(reviewId: reviewId, userId: userId, reviewTitle: reviewTitle, reviewContent: reviewContent, postDate: date, rating: rating, parentItem: parentId)
            
            completion(newReview, nil)
            
        } catch {
            completion(nil, APICollectionError.databaseError)
            Log.error("Could not add document")
        }
        
        
    }
    
    // get specific review
    public func getReviewById(id: String, completion: @escaping (ReviewItem?, Error?) -> Void) {
        
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(nil ,APICollectionError.databaseError)
            return
        }
        
        let collection = db!["reviews"]
        
        do {
            
            let objectId = try ObjectId(id)
            guard let result = try collection.findOne("_id" == objectId) else {
                Log.error("Could not get any reviews")
                completion(nil, APICollectionError.databaseError)
                return
            }
            
            if let reviewTitle = String(result["reviewtitle"]), let reviewContent = String(result["reviewcontent"]), let postDate = Date(result["date"]), let rating = Int(result["rating"]), let parentId = String(result["parentid"]), let userId = String(result["userid"]) {
                
                let newReview = ReviewItem(reviewId: id, userId: userId, reviewTitle: reviewTitle, reviewContent: reviewContent, postDate: postDate, rating: rating, parentItem: parentId)
                
                completion(newReview, nil)
                
                } else {
                
                Log.error("Could not get review fields")
                completion(nil, APICollectionError.parseError)
            }
            
        } catch {
            
        }
    }
    
    // edit review
    public func editReview(id: String, reviewTitle: String?, reviewContent: String?, rating: Int?, completion: @escaping (ReviewItem?, Error?) -> Void) {
        
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(nil, APICollectionError.databaseError)
            return
        }
        
        let collection = db!["reviews"]
        
        do {
            
            let objectId = try ObjectId(id)
            let result = try collection.findOne("_id" == objectId)
            
            guard let review = result else {
                Log.error("Could not get review")
                completion(nil, APICollectionError.databaseError)
                return
            }
            
            if let dbTitle = String(review["reviewtitle"]), let dbContent = String(review["reviewcontent"]), let dbUserId = String(review["userid"]), let dbParentId = String(review["parentid"]), let dbRating = Int(review["rating"]) {
                
                let title = reviewTitle ?? dbTitle
                let content = reviewContent ?? dbContent
                let r = rating ?? dbRating
                let date = Date()
                
                var doc = Document()
                doc["reviewtitle"] = title
                doc["reviewcontent"] = content
                doc["rating"] = r
                doc["date"] = date
                doc["userid"] = dbUserId
                doc["parentid"] = dbParentId
                
                
                try collection.update("_id" == objectId, to: doc)
                
                let newReview = ReviewItem(reviewId: id, userId: dbUserId, reviewTitle: title, reviewContent: content, postDate: date, rating: r, parentItem: dbParentId)
                
                completion(newReview, nil)
            } else {
            
            Log.error("Could not get review details")
            completion(nil, APICollectionError.parseError)
            
            }
  
        } catch {
            Log.error("Communications error")
            completion(nil, APICollectionError.databaseError)
        }
        
    }
    
    // count review
    public func countReviews(parentId: String, completion: @escaping (Int?, Error?) -> Void) {
        
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(nil, APICollectionError.databaseError)
            return
        }
        
        let collection = db!["reviews"]
        
        do {
            
            let results = try collection.find("parentid" == parentId)
            let count = try results.count()
            
            completion(count, nil)
        } catch {
            
            Log.error("Could not get reviews")
            completion(nil, APICollectionError.databaseError)
        }
        
    }
    
    // clear reviews
    public func clearReviews(completion: @escaping (Error?) -> Void) {
        
        guard let db = try? connectToDB(), db != nil else {
            Log.error("Could not connect to database")
            completion(nil)
            return
        }
        
        let collection = db!["reviews"]
        
        do {
            let results = try collection.find()
            
            for result in results {
                try collection.remove("_id" == result["_id"])
            }
            
            completion(nil)
        } catch {
            Log.error("Could not delete documents")
            completion(APICollectionError.databaseError)
        }
    }
    
}

