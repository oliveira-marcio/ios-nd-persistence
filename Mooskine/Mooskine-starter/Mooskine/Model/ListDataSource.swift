//
//  ListDataSource.swift
//  Mooskine
//
//  Created by Márcio Oliveira on 9/9/20.
//  Copyright © 2020 Udacity. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class ListDataSource<ObjectType: NSManagedObject, CellType: UITableViewCell>: NSObject, UITableViewDataSource, NSFetchedResultsControllerDelegate {
    
    private var viewManagedObjectContext: NSManagedObjectContext!
    private var backgroundManagedObjectContext: NSManagedObjectContext!
    private var fetchedResultsController: NSFetchedResultsController<ObjectType>!
    private var tableView: UITableView!
    private var configureFunction: (CellType, ObjectType) -> Void
    
    init(
        tableView: UITableView,
        dataController: DataController,
        fetchRequest: NSFetchRequest<ObjectType>,
        cacheName: String,
        configure: @escaping (CellType, ObjectType) -> Void
    ) {
        self.viewManagedObjectContext = dataController.viewContext
        self.backgroundManagedObjectContext = dataController.backgroundContext
        self.tableView = tableView
        self.configureFunction = configure
        
        super.init()
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: viewManagedObjectContext, sectionNameKeyPath: nil, cacheName: cacheName)
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
    }
    
    func releaseFetchedResultsController() {
        fetchedResultsController = nil
    }
    
     /// Adds a new notebook to the end of the `notebooks` array
    func addNotebook(name: String) {
        viewManagedObjectContext.perform {
            let notebook = Notebook(context: self.viewManagedObjectContext)
            notebook.name = name
            notebook.creationDate = Date()

            try? self.viewManagedObjectContext.save()
        }
    }
    
    /// Adds a new `Note` to the end of the `notebook`'s `notes` array
    func addNote(notebook: Notebook) {
        viewManagedObjectContext.perform {
            let note = Note(context: self.viewManagedObjectContext)
            note.attributedText = NSAttributedString(string: "New Note")
            note.creationDate = Date()
            note.notebook = notebook

            try? self.viewManagedObjectContext.save()
        }
    }

    func updateNote(_ note: Note, with attributedText: NSAttributedString) {
        viewManagedObjectContext.perform {
            note.attributedText = attributedText
            try? self.viewManagedObjectContext.save()
        }
    }

    func updateNote(_ note: Note, with processedAttributedText: @escaping () -> NSAttributedString) {
        backgroundManagedObjectContext.perform {
            let backgroundNote = self.backgroundManagedObjectContext.object(with: note.objectID) as! Note
            backgroundNote.attributedText = processedAttributedText()

            try?self.backgroundManagedObjectContext.save()
        }
    }

     /// Deletes the item at the specified index path
    func deleteItem(at indexPath: IndexPath) {
        let itemToDelete = fetchedResultsController.object(at: indexPath)
        self.viewManagedObjectContext.delete(itemToDelete)

        viewManagedObjectContext.perform {
            try? self.viewManagedObjectContext.save()
        }
    }
    
    func getItem(at indexPath: IndexPath) -> ObjectType {
        return fetchedResultsController.object(at: indexPath)
    }
    
    func getSection(at index: Int) -> NSFetchedResultsSectionInfo?{
        return fetchedResultsController.sections?[index]
    }
    
     // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let object = fetchedResultsController.object(at: indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: "\(CellType.self)", for: indexPath) as! CellType
        
        configureFunction(cell, object)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        switch editingStyle {
        case .delete: deleteItem(at: indexPath)
        default: () // Unsupported
        }
    }
    
     // MARK: - Fetched Results Controller Delegate
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            tableView.reloadRows(at: [indexPath!], with: .fade)
        case .move:
            tableView.moveRow(at: indexPath!, to: newIndexPath!)
        default:
            fatalError("Invalid change type in controller(_:didChange:at:for:newIndexPath). Only .insert, .delete, .update and .move should be possible.")
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        let indexSet = IndexSet(integer: sectionIndex)
        switch type {
        case .insert: tableView.insertSections(indexSet, with: .fade)
        case .delete: tableView.deleteSections(indexSet, with: .fade)
        default:
            fatalError("Invalid change type in controller(_:didChange:atSectionIndex:for:). Only .insert or .delete should be possible.")
        }
    }

    private var saveObserverTokens = [String: Any]()

    // MARK: - ManagedObjectContext Changes Notifications
    
    func addSaveNotificationObserver(key: String, handler: @escaping (Notification) -> Void) {
        removeSaveNotificationObserver(key: key)
        saveObserverTokens[key] = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: viewManagedObjectContext, queue: nil) { notification in
            DispatchQueue.main.async {
                handler(notification)
            }
        }
    }

    func removeSaveNotificationObserver(key: String) {
        if let token = saveObserverTokens[key] {
            NotificationCenter.default.removeObserver(token)
            saveObserverTokens.removeValue(forKey: key)
        }
    }
}
