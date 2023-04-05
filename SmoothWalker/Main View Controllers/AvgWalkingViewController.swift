//
//  AvgWalkingViewController.swift
//  SmoothWalker
//
//  Created by Torin Wiese (Work) on 4/3/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import Foundation
import HealthKit
import UIKit

class AvgWalkingViewController: DataTableViewController, HealthQueryDataSource {
    
    let calendar: Calendar = .current
    
    init() {
        super.init(dataTypeIdentifier: HKQuantityTypeIdentifier.walkingSpeed.rawValue)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func performQuery(completion: @escaping () -> Void) {
        let now = Date()
        let yesterDay = getLastDayStartDate()
        let lastWeek = getLastWeekStartDate()
        let lastMonth = getLastMonthStartDate()
        
        let dayPredicate = createLastDayPredicate()
        let weekPredicate = createLastWeekPredicate()
        let monthPredicate = createLastMonthPredicate()
       
        performQuery(startDate: yesterDay, predicate: dayPredicate, completion: completion)
        performQuery(startDate: lastWeek, predicate: weekPredicate, completion: completion)
        performQuery(startDate: lastMonth, predicate: monthPredicate, completion: completion)
    }
    
    func performQuery(startDate: Date, predicate: NSPredicate, completion: @escaping() -> Void) {
        let statsOptions = getStatisticsOptions(for: HKQuantityTypeIdentifier.walkingSpeed.rawValue)
        let quantityType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.walkingSpeed)!
        
        let query = HKStatisticsCollectionQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: statsOptions, anchorDate: createAnchorDate(), intervalComponents: DateComponents(day: 1))
        
        
        let updateInterfaceWithStatistics: (HKStatisticsCollection) -> Void = { statisticsCollection in
            let avg = statisticsCollection.statistics()[0].averageQuantity()
            self.dataValues.append(HealthDataTypeValue(startDate: startDate, endDate: Date(), value: (avg?.doubleValue(for: HKUnit(from: "m/s")))!))
            
            completion()
        }
        
        query.initialResultsHandler = { query, statisticsCollection, error in
            if let statisticsCollection = statisticsCollection {
                updateInterfaceWithStatistics(statisticsCollection)
            }
        }
        
        query.statisticsUpdateHandler = { [weak self] query, statistics, statisticsCollection, error in
            // Ensure we only update the interface if the visible data type is updated
            if let statisticsCollection = statisticsCollection, query.objectType?.identifier == self?.dataTypeIdentifier {
                updateInterfaceWithStatistics(statisticsCollection)
            }
        }
        
        HealthData.healthStore.execute(query)
    }
    
    // MARK: - View Life Cycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        HealthData.requestHealthDataAccessIfNeeded(dataTypes: [HKQuantityTypeIdentifier.walkingSpeed.rawValue]) { (success) in
            if success {
                self.calculateWalkingSpeeds()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    func calculateWalkingSpeeds() {
        performQuery {
            DispatchQueue.main.async { [weak self] in
                self?.reloadData()
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier) as? DataTypeTableViewCell else {
            return DataTypeTableViewCell()
        }
        
        let dataValue = dataValues[indexPath.row]
        
        cell.textLabel?.text = formattedValue(dataValue.value, typeIdentifier: dataTypeIdentifier)
        cell.detailTextLabel?.text = dateFormatter.string(from: dataValue.startDate) + " - " + dateFormatter.string(from: dataValue.endDate)
        
        return cell
    }
}
