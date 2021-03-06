import Foundation
import Credentials

typealias JSONDictionary = [String: Any]

protocol DictionaryConvertable {
    func toDict() -> JSONDictionary
}

protocol Item {
    var id: String { get }
    var name: String { get }
    var date: String { get }
}

public protocol ResturauntAPI {
    
    var jwtCredentials: Credentials { get }
    
    // MARK: Menu items
    
    // Get all menu items
    func getMenuItems(completion: @escaping ([MenuItem]?, Error?) -> Void)
    
    // Get specific menu item
    func getMenuItem(id: String, completion: @escaping (MenuItem?, Error?) -> Void)
    
    // Add new menu item
    func addMenuItem(itemType: String, itemSubType: String, itemName: String, itemPrice: Double, imgUrl: String, completion: @escaping (MenuItem?, Error?) -> Void)
    
    // Edit menu item
    func editMenuItem(id: String, itemType: String?, itemSubType: String?, itemName: String?, itemPrice: Double?, imgUrl: String?, completion: @escaping (MenuItem?, Error?) -> Void)
    
    // delete menu item
    func deleteMenuItem(id: String, completion: @escaping (Error?) -> Void)
    
    // clear all items
    func clearMenuItems(completion: (Error?) -> Void)
    
    // get menu items by type
    func getItemsByType(type: String, subType: String?, completion: @escaping ([MenuItem]?, Error?) -> Void)
    
    // get count of all menu items
    func countMenuItems(completion: @escaping (Int?, Error?) ->Void)
    
    // MARK: - Event items
    
    // get all events
    func getEventItems(completion: @escaping ([EventItem]?, Error?) -> Void)
    
    // get specific event item
    func getEventItem(id: String, completion: @escaping (EventItem?, Error?) ->Void)
    
    // add event item
    func addEvent(eventName: String, eventDate: String, eventDescription: String, completion: @escaping (EventItem?, Error?) -> Void)
    
    // edit event item
    func editEvent(id: String, eventName: String?, eventDate: String?, eventDescription: String?, completion: @escaping (EventItem?, Error?) -> Void)
    
    // delete event
    func deleteEvent(id: String, completion: @escaping (Error?) -> Void)
    
    // count events
    func countEventItems(completion: @escaping (Int?, Error?) -> Void)
    
    // clear events
    func clearEventItems(completion: (Error?) -> Void)
    
    // MARK: - Reviews
    // get all reviews for item
    func getAllReviewsForItem(parentId: String, completion: @escaping ([ReviewItem]?, Error?) -> Void)
    
    // get specific review
    func getReviewById(id: String, completion: @escaping (ReviewItem?, Error?) -> Void)
    
    // add review
    func addReview(parentId: String, userId: String, reviewTitle: String, reviewContent: String, rating: Int, completion: @escaping (ReviewItem?, Error?) -> Void)
    
    // edit review
    func editReview(id: String, reviewTitle: String?, reviewContent: String?, rating: Int?, completion: @escaping (ReviewItem?, Error?) -> Void)
    
    // count review
    func countReviews(parentId: String, completion: @escaping (Int?, Error?) -> Void)
    
    // clear reviews
    func clearReviews(completion: @escaping (Error?) -> Void)
}
