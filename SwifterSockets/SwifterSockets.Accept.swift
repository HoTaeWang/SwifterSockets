// =====================================================================================================================
//
//  File:       SwifterSockets.Accept.swift
//  Project:    SwifterSockets
//
//  Version:    0.9
//
//  Author:     Marinus van der Lugt
//  Website:    http://www.balancingrock.nl/swiftersockets.html
//
//  Copyright:  (c) 2014-2016 Marinus van der Lugt, All rights reserved.
//
//  License:    Use this code any way you like with the following three provision:
//
//  1) You are NOT ALLOWED to redistribute this source code.
//
//  2) You ACCEPT this source code AS IS without any guarantees that it will work as intended. Any liability from its
//  use is YOURS.
//
//  3) Recompensation for any form of damage IS LIMITED to the price you paid for this source code.
//
//  Prices/Quotes for support, modifications or enhancements can be obtained from: sales@balancingrock.nl
//
// =====================================================================================================================
//
// Note: The 'accept' functions are only needed for servers that need to handle more than one transfer after an 'init'.
// The 'accept' calls return a socket descriptor that is different from the socket on which the accept function was
// called. The callee is responsible for closing the returned socket descriptor.
//
// =====================================================================================================================
// PLEASE let me know about bugs, improvements and feature requests. (rien@balancingrock.nl)
// =====================================================================================================================
//
// History
// w0.9.1 AcceptTelemetry now inherits from NSObject
// v0.9.0 Initial release
// =====================================================================================================================

import Foundation


extension SwifterSockets {
    
    
    /**
     The result for the accept function accept. Possible values are:
     
     - ACCEPTED(socket: Int32)
     - ERROR(message: String)
     - TIMEOUT
     - ABORTED
     
     */
    
    enum AcceptResult: CustomStringConvertible, CustomDebugStringConvertible {
        
        
        /// A connection was accepted, the socket descriptor is enclosed
        
        case ACCEPTED(socket: Int32)
        
        
        /// An error occured, the error message is enclosed.
        
        case ERROR(message: String)
        
        
        /// A timeout occured.
        
        case TIMEOUT
        
        
        /// The wait for a connection request was aborted by writing 'true' to 'stopAccepting'.
        
        case ABORTED
        
        
        /// The CustomStringConvertible protocol
        
        var description: String {
            switch self {
            case .TIMEOUT: return "Timeout"
            case .ABORTED: return "Aborted"
            case let .ERROR(message: msg): return "Error(message: \(msg))"
            case let .ACCEPTED(socket: num): return "Accepted(socket: \(num))"
            }
        }
        
        
        /// The CustomDebugStringConvertible protocol
        
        var debugDescription: String { return description }
    }
    
    
    /// This exception can be thrown by the _OrThrow functions. Notice that the ABORTED case is not an error per se but is always in response to an request to abort.
    
    enum AcceptException: ErrorType, CustomStringConvertible, CustomDebugStringConvertible {
        
        
        /// The string contains a textual description of the error
        
        case MESSAGE(String)
        
        
        /// A timeout occured
        
        case TIMEOUT
        
        
        /// The accept was aborted throu the abort flag
        
        case ABORTED
        
        
        /// The CustomStringConvertible protocol
        
        var description: String {
            switch self {
            case .TIMEOUT: return "Timeout"
            case .ABORTED: return "Aborted"
            case let .MESSAGE(msg): return "Message(\(msg))"
            }
        }
        
        
        /// The CustomDebugStringConvertible protocol
        
        var debugDescription: String { return description }
    }
    
    
    /// The telemetry that is available from the accept call. The values are read-only.
    
    class AcceptTelemetry: NSObject, CustomDebugStringConvertible {
        
        
        /// The number of times the accept loop has been run so far, updated 'life'.
        
        var loopCounter: Int = 0
        
        
        /// The number of accepted connection requests
        
        var acceptedConnections: Int32 = 0
        
        
        /// The time the accept was started, set once at the start of the function call.
        
        var startTime: NSDate? {
            get {
                return synchronized(self, { self._startTime })
            }
            set {
                synchronized(self, { self._startTime = newValue })
            }
        }
        
        private var _startTime: NSDate?
        
        
        /// The time the timeout (if used) will terminate the accept call, set once at the start of the function call.
        
        var timeoutTime: NSDate? {
            get {
                return synchronized(self, { self._timeoutTime })
            }
            set {
                synchronized(self, { self._timeoutTime = newValue })
            }
        }
        
        private var _timeoutTime: NSDate?

        
        
        /// The time the accept function exited, set once at the exit of the call.
        
        var endTime: NSDate? {
            get {
                return synchronized(self, { self._endTime })
            }
            set {
                synchronized(self, { self._endTime = newValue })
            }
        }
        
        private var _endTime: NSDate?

        
        /// A copy of the result of the return parameter.
        
        var result: AcceptResult? {
            get {
                return synchronized(self, { self._result })
            }
            set {
                synchronized(self, { self._result = newValue })
            }
        }
        
        private var _result: AcceptResult?
        
        
        /// Remote IP address
        
        var clientAddress: String? {
            get {
                return synchronized(self, { self._clientAddress })
            }
            set {
                synchronized(self, { self._clientAddress = newValue })
            }
        }
        
        private var _clientAddress: String?
        
        
        /// Remote port number
        
        var clientPort: String? {
            get {
                return synchronized(self, { self._clientPort })
            }
            set {
                synchronized(self, { self._clientPort = newValue })
            }
        }
        
        private var _clientPort: String?
        
        
        /// The CustomStringConvertible protocol
        
        override var description: String {
            var str = ""
            str += "loopCounter = \(loopCounter)\n"
            str += "acceptedConnections = \(acceptedConnections)\n"
            str += "startTime = \(startTime)\n"
            str += "timeoutTime = \(timeoutTime)\n"
            str += "endTime = \(endTime)\n"
            str += "result = \(result)\n"
            str += "clientAddress = \(clientAddress)\n"
            str += "clientPort = \(clientPort)\n"
            return str
        }
        
        
        /// The CustomDebugStringConvertible protocol
        
        override var debugDescription: String { return description }
    }

    
    /**
     Waits for a connection request to arrive on the given socket descriptor. The function returns when a connection has been accepted, when an error occured, when a timeout occured or when the static variable 'abortFlag' is set to 'true'. This function does not close any socket. This function is the basis for all other SwifterSockets.acceptXXX calls.
     
     - Parameter socket: The socket descriptor on which accept will listen for connection requests. This socket descriptor should have been initialized with "InitServerSocket" previously.
     - Parameter abortFlag: The function will terminate as soon as possible (see polling interval) when this variable is set to 'true'. This variable must be set to 'false' before the call, otherwise the function will terminate immediately.
     - Parameter abortFlagPollInterval: In the default mode (i.e. timeout == nil) the function will poll the inout variable abortFlag to abort the accept procedure. The interval is the time between evaluations of the abortFlag. If the argument is nil, the timeout argument *must* be non-nil. When used, the argument must be > 0. Setting this argument to an extremely low value wil result in high CPU loads, recommended minimum value is at least 1 second.
     - Parameter timeout: The maximum duration this function will wait for a connection request to arrive. When nil the abortFlag controls how long the accept loop will run (see also pollInterval). PollInterval and timeout can be used simultaniously.
     - Parameter telemetry: This class can be used if the callee wishes to monitor the accept function. See class description for details. If argument errors are found, the telemetry will not be updated.

     - Returns: ACCEPTED with a socket descriptor, ERROR with an error message, TIMEOUT or ABORTED. When a socket descriptor is returned its SIGPIPE exception is disabled.
     */
    
    static func acceptNoThrow(
        socket: Int32,
        inout abortFlag: Bool,
        abortFlagPollInterval: NSTimeInterval?,
        timeout: NSTimeInterval? = nil,
        telemetry: AcceptTelemetry? = nil)
        -> AcceptResult
    {
        // Protect against illegal argument values
        
        guard let _ = timeout ?? abortFlagPollInterval else {
            return .ERROR(message: "At least one of timeout or abortFlagPollInterval must be specified")
        }
        
        if abortFlagPollInterval != nil {
            if abortFlagPollInterval! == 0.0 {
                return .ERROR(message: "abortFlagPollInterval may not be 0")
            }
        }
        
        
        // Set a timeout if necessary
        
        let startTime = NSDate()
        telemetry?.startTime = startTime
        
        var timeoutTime: NSDate?
        if timeout != nil {
            timeoutTime = startTime.dateByAddingTimeInterval(timeout!)
            telemetry?.timeoutTime = timeoutTime
        }
        
        
        // =====================
        // Start the accept loop
        // =====================
        
        ACCEPT_LOOP: while abortFlag == false {
            
            
            // ===========================================================================
            // Calculate time to wait until either the pollInterval or the timeout expires
            // ===========================================================================
            
            let localTimeout: NSTimeInterval! = timeoutTime?.timeIntervalSinceNow ?? abortFlagPollInterval
            
            if localTimeout < 0.0 {
                telemetry?.endTime = NSDate()
                telemetry?.result = .TIMEOUT
                return .TIMEOUT
            }
            
            let availableSeconds = Int(localTimeout)
            let availableUSeconds = Int32((localTimeout - Double(availableSeconds)) * 1_000_000.0)
            var availableTimeval = timeval(tv_sec: availableSeconds, tv_usec: availableUSeconds)
            
            
            // =====================================================================================
            // Use the select API to wait for data to arrive on our socket within the timeout period
            // =====================================================================================
            
            let numOfFd:Int32 = socket + 1
            var readSet:fd_set = fd_set(fds_bits: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
            
            fdSet(socket, set: &readSet)
            let status = select(numOfFd, &readSet, nil, nil, &availableTimeval)
            
            // Because we only specify 1 FD, we do not need to check on which FD the event was received
            
            
            // Evaluate the result of the select call
            
            if status == 0 { // nothing happened
                
                
                // Check for timeout
                
                if let t = timeoutTime?.timeIntervalSinceNow where t < 0.0 {
                    telemetry?.endTime = NSDate()
                    telemetry?.result = .TIMEOUT
                    return .TIMEOUT
                }
                
                
                // Increment the accept loop counter as a "sign of life"
                
                telemetry?.loopCounter += 1
                
                
                // Test for abort
                
                continue
            }
            
            
            // =======================================
            // Accept the incoming connection request
            // =======================================
            
            var connectedAddrInfo = sockaddr(sa_len: 0, sa_family: 0, sa_data: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
            var connectedAddrInfoLength = socklen_t(sizeof(sockaddr))
            
            let receiveSocket = accept(socket, &connectedAddrInfo, &connectedAddrInfoLength)
            
            // Evalute the result of the accept call
            
            if receiveSocket == -1 { // Error
                
                let strerr = String(UTF8String: strerror(errno)) ?? "Unknown error code"
                telemetry?.endTime = NSDate()
                telemetry?.result = .ERROR(message: strerr)
                return .ERROR(message: strerr)
                
                
            } else {  // Success, return the accepted socket
                
                
                // ================================================
                // Set the socket option: prevent SIGPIPE exception
                // ================================================
                
                var optval = 1;
                
                let status = setsockopt(
                    receiveSocket,
                    SOL_SOCKET,
                    SO_NOSIGPIPE,
                    &optval,
                    socklen_t(sizeof(Int)))
                
                if status == -1 {
                    let strError = String(UTF8String: strerror(errno)) ?? "Unknown error code"
                    close(receiveSocket)
                    return .ERROR(message: strError)
                }

                
                // ===========================================
                // get Ip Addres and Port number of the client
                // ===========================================
                
                let (ipOrNil, portOrNil) = sockaddrDescription(&connectedAddrInfo)
                    
                telemetry?.clientAddress = ipOrNil ?? "Unknown client address"
                telemetry?.clientPort = portOrNil ?? "Unknown client port"
                telemetry?.endTime = NSDate()
                telemetry?.result = .ACCEPTED(socket: receiveSocket)
                telemetry?.acceptedConnections += 1
                
                return .ACCEPTED(socket: receiveSocket)
            }
        }
        
        // ==================
        // Accept was aborted
        // ==================
        
        telemetry?.endTime = NSDate()
        telemetry?.result = .ABORTED

        return .ABORTED
    }

    
    /**
     Waits for a connection request to arrive on the given socket descriptor. The function returns when a connection has been accepted, when an error occured, when a timeout occured or when the static variable 'abortFlag' is set to 'true'. This function does not close any socket. This function is excepection based a wrapper for accept.
     
     - Parameter socket: The socket descriptor on which accept will listen for connection requests. This socket descriptor should have been initialized with "InitServerSocket" previously.
     - Parameter abortFlag: The function will terminate as soon as possible (see polling interval) when this variable is set to 'true'. This variable must be set to 'false' before the call, otherwise the function will terminate immediately.
     - Parameter abortFlagPollInterval: In the default mode (i.e. timeout == nil) the function will poll the inout variable abortFlag to abort the accept procedure. The interval is the time between evaluations of the abortFlag. If the argument is nil, the timeout argument *must* be non-nil. When used, the argument must be > 0. Setting this argument to an extremely low value wil result in high CPU loads, recommended minimum value is at least 1 second.
     - Parameter timeout: The maximum duration this function will wait for a connection request to arrive. When nil the abortFlag controls how long the accept loop will run (see also pollInterval). PollInterval and timeout can be used simultaniously.
     - Parameter telemetry: This class can be used if the callee wishes to monitor the accept function. See class description for details. If argument errors are found, the telemetry will not be updated.
     
     - Returns: The socket descriptor on which data can be received. This will be an 'accept'-ed socket, i.e. different from the socket argument. The callee is responsible for closing this socket.
     
     - Throws: The AcceptException when something fails.
     */
    
    static func acceptOrThrow(
        socket: Int32,
        inout abortFlag: Bool,
        abortFlagPollInterval: NSTimeInterval?,
        timeout: NSTimeInterval? = nil,
        telemetry: AcceptTelemetry?) throws -> Int32
    {
        
        let result = acceptNoThrow(socket, abortFlag: &abortFlag, abortFlagPollInterval: abortFlagPollInterval, timeout: timeout, telemetry: telemetry)
        
        switch result {
        case .TIMEOUT: throw AcceptException.TIMEOUT
        case .ABORTED: throw AcceptException.ABORTED
        case let .ERROR(message: msg): throw AcceptException.MESSAGE(msg)
        case let .ACCEPTED(socket: socket):
            return socket
        }
    }
}