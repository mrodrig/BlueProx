//
//  ViewController.swift
//  BlueProx
//
//  Copyright © 2020 Massachusetts Institute of Technology. All rights reserved.
//

import UIKit
import CoreBluetooth
import CoreMotion


class ViewController: UIViewController, CBCentralManagerDelegate {
    
    // -----------------------------------------------------------------------------
    // Parameters
    // -----------------------------------------------------------------------------
    
    // Detector parameters
    var M = 5                       // Samples that must cross threshold
    var N = 20                      // Total number of samples
    var rssiThresh = -65            // Threshold RSSI
    
    // Sensor parameters
    var scanRateHz = 4.0            // Number of times per second the Bluetooth scan is restarted
    var accelRateHz = 4.0           // Number of times per second to get accelerometer data
    var gyroRateHz = 4.0            // Number of times per second to get gyroscope data
    
    // Enable/disable logging of sensors - all are enabled when the app launches
    var enableBT = true
    var enableProx = false
    var enableAccel = true
    var enableGyro = true
    var enableGPS = true
    
    // Sensor logging - when the app launches, logging is not running yet
    var enableLogger = false
    var logToConsole = false
    var logToFile = true
    var logFileName = "log.txt"
    
    // -----------------------------------------------------------------------------
    // Variables
    // -----------------------------------------------------------------------------
    
    var centralManager : CBCentralManager!
    var motionManager = CMMotionManager()
    var fileManager = FileManager.default
    var fileUpdater : FileHandle!
    var scanTimer = Timer()
    var accelTimer = Timer()
    var logTimer = Timer()
    var rssiCount = 0
    var currRange = 10
    var appliedRange = -1
    var logFile : URL!
    var uuids : [String] = []
    var mtx : [[Int]] = []
    var mtxPtr : [Int] = []
    var nArr : [Int] = []
    var detArr : [Int] = []
    
    // -----------------------------------------------------------------------------
    // Outlets
    // -----------------------------------------------------------------------------
    
    // Top level containers
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    
    // Bluetooth switch
    @IBOutlet weak var btSwitch: UISwitch!
    @IBOutlet weak var btSwitchText: UILabel!
    
    // Proximity sensor switch
    @IBOutlet weak var proxSwitch: UISwitch!
    @IBOutlet weak var proxSwitchText: UILabel!
    
    // Range
    @IBOutlet weak var rangeStepper: UIStepper!
    @IBOutlet weak var rangeText: UILabel!
    @IBOutlet weak var rangeUnitText: UILabel!
    @IBOutlet weak var rangeAppliedText: UILabel!
    
    // Logger on/off and file size
    @IBOutlet weak var loggerSwitch: UISwitch!
    @IBOutlet weak var loggerText: UILabel!
    @IBOutlet weak var logSizeText: UILabel!
    
    // Bluetooth counters
    @IBOutlet weak var rssiCountText: UILabel!
    @IBOutlet weak var deviceCountText: UILabel!
    
    // Detector parameters
    @IBOutlet weak var rssiText: UILabel!
    @IBOutlet weak var nText: UILabel!
    @IBOutlet weak var mText: UILabel!
    
    // Name label group
    @IBOutlet weak var nameLabel0: UILabel!
    @IBOutlet weak var nameLabel1: UILabel!
    @IBOutlet weak var nameLabel2: UILabel!
    @IBOutlet weak var nameLabel3: UILabel!
    @IBOutlet weak var nameLabel4: UILabel!
    @IBOutlet weak var nameLabel5: UILabel!
    @IBOutlet weak var nameLabel6: UILabel!
    @IBOutlet weak var nameLabel7: UILabel!
    @IBOutlet weak var nameLabel8: UILabel!
    @IBOutlet weak var nameLabel9: UILabel!
    var nameLabelArr : [UILabel] = []
    
    // RSSI label group
    @IBOutlet weak var rssiLabel0: UILabel!
    @IBOutlet weak var rssiLabel1: UILabel!
    @IBOutlet weak var rssiLabel2: UILabel!
    @IBOutlet weak var rssiLabel3: UILabel!
    @IBOutlet weak var rssiLabel4: UILabel!
    @IBOutlet weak var rssiLabel5: UILabel!
    @IBOutlet weak var rssiLabel6: UILabel!
    @IBOutlet weak var rssiLabel7: UILabel!
    @IBOutlet weak var rssiLabel8: UILabel!
    @IBOutlet weak var rssiLabel9: UILabel!
    var rssiLabelArr : [UILabel] = []
    
    // Proximity label group
    @IBOutlet weak var proximityLabel0: UILabel!
    @IBOutlet weak var proximityLabel1: UILabel!
    @IBOutlet weak var proximityLabel2: UILabel!
    @IBOutlet weak var proximityLabel3: UILabel!
    @IBOutlet weak var proximityLabel4: UILabel!
    @IBOutlet weak var proximityLabel5: UILabel!
    @IBOutlet weak var proximityLabel6: UILabel!
    @IBOutlet weak var proximityLabel7: UILabel!
    @IBOutlet weak var proximityLabel8: UILabel!
    @IBOutlet weak var proximityLabel9: UILabel!
    var proximityLabelArr : [UILabel] = []
        
    // -----------------------------------------------------------------------------
    // Primary setup
    // -----------------------------------------------------------------------------
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Prevent screen from turning off
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Pack labels into arrays
        nameLabelArr = [nameLabel0, nameLabel1, nameLabel2, nameLabel3, nameLabel4, nameLabel5, nameLabel6, nameLabel7, nameLabel8, nameLabel9]
        rssiLabelArr = [rssiLabel0, rssiLabel1, rssiLabel2, rssiLabel3, rssiLabel4, rssiLabel5, rssiLabel6, rssiLabel7, rssiLabel8, rssiLabel9]
        proximityLabelArr = [proximityLabel0, proximityLabel1, proximityLabel2, proximityLabel3, proximityLabel4, proximityLabel5, proximityLabel6, proximityLabel7, proximityLabel8, proximityLabel9]
        
        // Display the detector parameters
        nText.text = N.description
        mText.text = M.description
        rssiText.text = rssiThresh.description
        
        // Logger switch initially disabled
        loggerSwitch.isEnabled = false
        
        // Create the log file
        if logToFile {
            logFile = getDir().appendingPathComponent(logFileName)
            fileManager.createFile(atPath: logFile.path, contents: nil, attributes: nil)
            do {
                try fileUpdater = FileHandle(forUpdating: logFile)
            }
            catch {
                print("Error making file updater")
            }
        }
        
        // Log the device model
        let modelName = UIDevice.modelName
        print("Device: " + modelName)
      let modelStr = "Device," + Utility.getTimestamp() + "," + modelName
        writeToLog(modelStr)
        
        // Show log file size every second
        logSizeLoop()
        
        // Make the bluetooth manager
        centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
        
        // Proximity sensor is always disabled for now
        proxSwitch.setOn(false, animated: true)
        proxSwitch.isEnabled = false
        proxSwitchText.textColor = UIColor.gray
        
        // Start sensors
        if enableProx {
            startProximitySensor()
        }
        if enableAccel {
            startAccelerometers()
        }
        if enableGyro {
            startGyroscope()
        }
    }
    
    // Set up the scroll view
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.contentSize = contentView.frame.size;
    }
    
    // Hide the top status bar
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // -----------------------------------------------------------------------------
    // Logging functions
    // -----------------------------------------------------------------------------
    
    // Gets directory to save data
    func getDir() -> URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    // Writes to log file
    func writeToLogFile(_ s : String) {
        // Add a line break and write to the end of the file
        let s = s + "\n"
        fileUpdater.seekToEndOfFile()
        fileUpdater.write(s.data(using: .utf8)!)
    }
    
    // Log to console and/or file
    func writeToLog(_ s : String) {
        if logToConsole {
            print(s)
        }
        if logToFile {
            writeToLogFile(s)
        }
    }
    
    // Timer for checking the log size every second
    func logSizeLoop() {
        logTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(ViewController.updateLogSize), userInfo: nil, repeats: true)
    }
    
    // Updates log size text
    @objc func updateLogSize() {
        let logSize = logFile.fileSize/1000
        logSizeText.text = logSize.description
    }
    
    // -----------------------------------------------------------------------------
    // Button and switch callbacks
    // -----------------------------------------------------------------------------
    
    @IBAction func btSwitchChanged(_ sender: Any) {
        enableBT.toggle()
        print("Bluetooth switch changed to \(enableBT)")
    }
    
    @IBAction func proxSwitchChanged(_ sender: Any) {
        enableProx.toggle()
        print("Proximity switch changed to \(enableProx)")
    }
    
    @IBAction func accelSwitchChanged(_ sender: Any) {
        enableAccel.toggle()
        print("Accelerometer switch changed to \(enableAccel)")
    }
    
    @IBAction func gyroSwitchChanged(_ sender: Any) {
        enableGyro.toggle()
        print("Gyroscope switch changed to \(enableGyro)")
    }
    
    @IBAction func gpsSwitchChanged(_ sender: Any) {
        enableGPS.toggle()
        print("GPS switch changed to \(enableGPS)")
    }
    
    // Applies range (writes to log) and updates range text color to green. Once
    // this has been done, the logger is able to be started.
    @IBAction func rangeButtonPressed(_ sender: Any) {
        if currRange != appliedRange {
            print("Applying range of \(currRange)")
            let rangeStr = "Range," + Utility.getTimestamp() + ",\(currRange)"
            writeToLog(rangeStr)
            appliedRange = currRange
            rangeText.textColor = UIColor.green
            rangeUnitText.textColor = UIColor.green
            rangeAppliedText.text = "Range is applied"
            rangeAppliedText.textColor = UIColor.green
            loggerSwitch.isEnabled = true
        } else {
            print("Range of \(currRange) is already applied")
        }
    }
    
    // Updates range text. Anytime the range has not been applied it is red.
    // The logger is able to be started only when the range is not red.
    @IBAction func rangeChanged(_ sender: Any) {
        currRange = Int(rangeStepper.value)
        print("Range changed to \(currRange)")
        rangeText.text = currRange.description
        if currRange != appliedRange {
            rangeText.textColor = UIColor.red
            rangeUnitText.textColor = UIColor.red
            rangeAppliedText.text = "Range is not applied!"
            rangeAppliedText.textColor = UIColor.red
            loggerSwitch.isEnabled = false
        } else {
            rangeText.textColor = UIColor.green
            rangeUnitText.textColor = UIColor.green
            rangeAppliedText.text = "Range is applied"
            rangeAppliedText.textColor = UIColor.green
            loggerSwitch.isEnabled = true
        }
    }
    
    // Enable/disable logging switch. While we are logging the range cannot be changed.
    // And once logging is disabled, the range must be set again.
    @IBAction func loggerSwitchChanged(_ sender: Any) {
        enableLogger.toggle()
        print("Logger enable changed to \(enableLogger)")
        if enableLogger {
            loggerText.text = "Running"
            loggerText.textColor = UIColor.green
            rangeStepper.isEnabled = false
        } else {
            loggerText.text = "Off"
            loggerText.textColor = UIColor.gray
            appliedRange = -1
            rangeText.textColor = UIColor.red
            rangeUnitText.textColor = UIColor.red
            rangeAppliedText.text = "Range is not applied!"
            rangeAppliedText.textColor = UIColor.red
            loggerSwitch.isEnabled = false
            rangeStepper.isEnabled = true
        }
    }
    
    // Shares the log file (only if one exists)
    @IBAction func shareButtonPressed(_ sender: Any) {
        print("Share button pressed")
        if logToFile {
            let activityItem:NSURL = NSURL(fileURLWithPath:logFile.path)
            let activityVC = UIActivityViewController(activityItems: [activityItem], applicationActivities: nil)
            self.present(activityVC, animated: true, completion: nil)
        }
    }
    
    // -----------------------------------------------------------------------------
    // Proximity sensor functions
    // -----------------------------------------------------------------------------
    
    // Starts the proximity sensor
    func startProximitySensor() {
        let device = UIDevice.current
        device.isProximityMonitoringEnabled = true
        if device.isProximityMonitoringEnabled {
            NotificationCenter.default.addObserver(self, selector: #selector(proximityChanged(notification:)), name: NSNotification.Name(rawValue: "UIDeviceProximityStateDidChangeNotification"), object: device)
        }
    }
    
    // If proximity sensor is activated
    @objc func proximityChanged(notification: NSNotification) {
        if enableProx && enableLogger {
            let proxState = UIDevice.current.proximityState ? 1 : 0
            let proxStr = "Prox," + Utility.getTimestamp() + ",\(proxState)"
            writeToLog(proxStr)
        }
    }
    
    // -----------------------------------------------------------------------------
    // Accelerometer functions
    // -----------------------------------------------------------------------------
    
    // Starts the accelerometer sensors
    func startAccelerometers() {
        motionManager.accelerometerUpdateInterval = (1.0/accelRateHz)
        motionManager.startAccelerometerUpdates()
        accelTimer = Timer.scheduledTimer(timeInterval: (1.0/accelRateHz), target: self, selector: #selector(ViewController.getAccelerometers), userInfo: nil, repeats: true)
    }
    
    // Gets accelerometer data
    @objc func getAccelerometers() {
        if enableAccel && enableLogger {
            let data = self.motionManager.accelerometerData
            let accelStr = "Accel," + Utility.getTimestamp() + ",\(data!.acceleration.x.description)" + ",\(data!.acceleration.y.description)" + ",\(data!.acceleration.z.description)"
            writeToLog(accelStr)
        }
    }
    
    // -----------------------------------------------------------------------------
    // Gyroscope functions
    // -----------------------------------------------------------------------------
    
    // Starts the gyroscope sensor
    func startGyroscope() {
        motionManager.gyroUpdateInterval = (1.0/gyroRateHz)
        motionManager.startGyroUpdates()
        accelTimer = Timer.scheduledTimer(timeInterval: (1.0/gyroRateHz), target: self, selector: #selector(ViewController.getGyroscope), userInfo: nil, repeats: true)
    }
    
    // Gets gyroscope data
    @objc func getGyroscope() {
        if enableGyro && enableLogger {
            let data = self.motionManager.gyroData
            let gyroStr = "Gyro," + Utility.getTimestamp() + ",\(data!.rotationRate.x.description)" + ",\(data!.rotationRate.y.description)" + ",\(data!.rotationRate.z.description)"
            writeToLog(gyroStr)
        }
    }
    
    // -----------------------------------------------------------------------------
    // Bluetooth functions
    // -----------------------------------------------------------------------------
    
    // Start scanning
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            enableBT = true
            btSwitch.setOn(true, animated: true)
            btSwitch.isEnabled = true
            btSwitchText.textColor = UIColor.white
            print("Bluetooth is on, starting scans")
            scanTimerLoop()
        } else {
            enableBT = false
            btSwitch.setOn(false, animated: true)
            btSwitch.isEnabled = false
            btSwitchText.textColor = UIColor.gray
            print("Bluetooth is off")
        }
    }
    
    // Calls restartScan() periodically
    func scanTimerLoop() {
        scanTimer = Timer.scheduledTimer(timeInterval: (1.0/scanRateHz), target: self, selector: #selector(ViewController.restartScan), userInfo: nil, repeats: true)
    }
    
    // Restarts the scan
    @objc func restartScan() {
        if enableBT {
            if centralManager.state == .poweredOn {
                centralManager.stopScan()
                centralManager.scanForPeripherals(withServices: nil, options: nil)
            }
        }
    }
    
    // Main function for Bluetooth processing
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        // Get UUID
        let uuid = peripheral.identifier.uuidString
        
        // Parse advertisement data
        var advName = "None"
        var advPower = -999.0
        var advTime = -1.0
        for (i, j) in advertisementData {
            if i == "kCBAdvDataLocalName" {
                advName = j as! String
            } else if i == "kCBAdvDataTxPowerLevel" {
                advPower = j as! Double
            } else if i == "kCBAdvDataTimestamp" {
                advTime = j as! Double
            }
        }
        
        // Log if enabled
        if enableBT && enableLogger {
            let btStr = "BT," + Utility.getTimestamp() + "," + uuid + ",\(RSSI)" + "," + advName + ",\(advPower)" + ",\(advTime)"
            writeToLog(btStr)
        }
        
        // If we haven't seen this UUID, set up storage for it
        var uuidIdx = uuids.index(of: uuid)
        if uuidIdx == nil {
            uuids.append(uuid)
            uuidIdx = uuids.count - 1
            mtx.append([Int](repeating: 0, count: N))
            mtxPtr.append(0)
            nArr.append(0)
            detArr.append(0)
            deviceCountText.text = uuids.count.description
        }
        
        // M-of-N detector. This makes a decision for each sample based on the threshold.
        // If there are at least N samples, and M of the decisions declare detection, then
        // overall detection is declared. Possible detection values:
        //      0 - no detection
        //      1 - not enough info, but suspect no detection
        //      2 - not enough info, but suspect detection
        //      3 - detection
        
        // Count up to N measurements for each device
        if nArr[uuidIdx!] < N {
            nArr[uuidIdx!] += 1
        }
        // Filter out erroneous RSSI readings. Sometimes there are very large values, or
        // values that are lower than the receiver sensitivity.
        if (RSSI.intValue >= rssiThresh) && (RSSI.intValue < 0) && (RSSI.intValue > -110) {
            mtx[uuidIdx!][mtxPtr[uuidIdx!]] = 1
        } else {
            mtx[uuidIdx!][mtxPtr[uuidIdx!]] = 0
        }
        // Wrap pointer to the buffer when we reach N measurements
        mtxPtr[uuidIdx!] += 1
        if mtxPtr[uuidIdx!] == N {
            mtxPtr[uuidIdx!] = 0
        }
        // See if there are M positives within the N samples
        let s = mtx[uuidIdx!].reduce(0, +)
        if s >= M {
            if nArr[uuidIdx!] == N {
                detArr[uuidIdx!] = 3
            } else {
                detArr[uuidIdx!] = 2
            }
        } else {
            if nArr[uuidIdx!] == N {
                detArr[uuidIdx!] = 0
            } else {
                detArr[uuidIdx!] = 1
            }
        }
        
        // Update screen
        rssiCount += 1
        rssiCountText.text = rssiCount.description
        if uuidIdx! < nameLabelArr.count {
            nameLabelArr[uuidIdx!].text = String(advName.prefix(10))
            rssiLabelArr[uuidIdx!].text = RSSI.description
            let mNstr = "(\(s)/\(nArr[uuidIdx!]))"
            if detArr[uuidIdx!] == 0 {
                proximityLabelArr[uuidIdx!].text = "Far " + mNstr
                proximityLabelArr[uuidIdx!].textColor = UIColor.green
            } else if detArr[uuidIdx!] == 1 {
                proximityLabelArr[uuidIdx!].text = "Far? " + mNstr
                proximityLabelArr[uuidIdx!].textColor = UIColor.orange
            } else if detArr[uuidIdx!] == 2 {
                proximityLabelArr[uuidIdx!].text = "Close? " + mNstr
                proximityLabelArr[uuidIdx!].textColor = UIColor.yellow
            } else if detArr[uuidIdx!] == 3 {
                proximityLabelArr[uuidIdx!].text = "Close " + mNstr
                proximityLabelArr[uuidIdx!].textColor = UIColor.red
            }
        }

    }
    
}
