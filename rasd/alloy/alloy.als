// SIGNATURES

abstract sig Boolean {}
one sig TRUE extends Boolean {}
one sig FALSE extends Boolean {}

sig Username {}
sig Password {}
sig EmailAddress {}

sig Position {
	latitude: one Int,
	longitude: one Int
} {
	latitude > 0 and longitude > 0
}

sig DateTime {
	timestamp: one Int
} { 
	timestamp > 0 
}

sig User {
	username: one Username,
	password: one Password,
	email: one EmailAddress,
	//id: one Int,
	stationResearches: set StationsResearch,
	reservations: set Reservation,
	vehicles: set Vehicle,
	notifications: set Notification,
	paymentMethods: set PaymentMethod,
	payments: set Payment
} //{
	//id > 0
//}

sig StationsResearch {
	timestamp: one DateTime,
	position: one Position,
	nearbyStations: set ChargingStation,
	distanceRange: one Int
} {
	distanceRange > 0
}

sig Reservation {
	from: one DateTime,
	to: one DateTime,
	// check if id is needed
	socket: one Socket
} {
	from.timestamp < to.timestamp
}

sig ChargingSession {
	reservation: one Reservation,
	isFinished: one Boolean,
	energyConsumed: one Int,
	batteryStatusEstimation: one Int,
} {
	energyConsumed >= 0 and
	batteryStatusEstimation >= 0
}

sig Vehicle {
	vin: one Int,
	model: one CarModel,
	battery: one VehicleBattery
} {
	vin >= 0
}

sig CarModel {}
sig VehicleBattery {
	status: one Int
} {
	status > 0
}

abstract sig Notification {
	timestamp: one DateTime
}

sig ChargingEndedNotification extends Notification {
	chargingSession: one ChargingSession
}

sig ChargingSuggestion extends Notification {
	from: one DateTime,
	to: one DateTime,
	suggestedVehicle: one Vehicle,
	chargingStation: one ChargingStation
} {
	from.timestamp < to.timestamp
}

sig PaymentMethod {}
sig Payment {
	amount: one Int,
	paymentMethod: one PaymentMethod,
	CPOInfo: one CPOPaymentReceiver,
	chargingSession: one ChargingSession
} {
	amount > 0
}

sig CPO {
	chargingStations: set ChargingStation,
	paymentReceiverInfo: one CPOPaymentReceiver
}

sig CPOPaymentReceiver {}

sig ChargingStation {
	sockets: set Socket,
	position: one Position,
	availableDSO: set DSOEnergySource,
	batteries: set ChargingStationBattery, // check if lone or set
	currentEnergySource: one EnergySource,
	baseUnitPrice: one Int,
	specialOffer: lone SpecialOffer
} {
	baseUnitPrice > 0
}

sig SpecialOffer {
	unitPrice: one Int,
	validFrom: one DateTime,
	expiration: one DateTime
} {
	validFrom.timestamp < expiration.timestamp and 
	unitPrice > 0
}

sig Socket {
	type: one SocketType,
	chargingProfile: one ChargingProfile // check if one or set
	// current charging session (lone) ?
}

sig ChargingProfile {
	validFrom: one DateTime,
	validTo: one DateTime,
	schedules: set ChargingSchedulePeriod
	// recurrency kind
} {
	validFrom.timestamp < validTo.timestamp
}

sig ChargingSchedulePeriod {
	startTime: one DateTime, //not a real time (depends on the recurrency kind)
	powerLimit: one Int
} {
	powerLimit > 0
}

abstract sig SocketType {}
one sig SLOW extends SocketType {}
one sig FAST extends SocketType {}
one sig RAPID extends SocketType {} 

abstract sig EnergySource {
	maxEnergyFlow: one Int //see if actual energy flow is needed
} {
	maxEnergyFlow > 0
}

//Is the energy offer common to all CPO? Or a DSO can make different offers to different CPOs?
sig DSOEnergySource extends EnergySource {
	energyOffer: one DSOEnergyOffer // check if one or set
}

sig ChargingStationBattery {
	capacity: one Int,
	storageStatus: one Int,
	isInUse: one Boolean,
	isRecharging: one Boolean
} {
	capacity > 0 and storageStatus > 0 and
	(isInUse = TRUE implies isRecharging = FALSE) and
	(isRecharging = TRUE implies isInUse = FALSE)
}

sig DSOEnergyOffer {
	price: one Int,
	startTime: one DateTime,
	endTime: one DateTime
} {
	price > 0 and 
	startTime.timestamp < endTime.timestamp
} 

------------------------------------------------------------------------------------------------
// FUNCTIONS

fun sockets [c: CPO] : set Socket {
	c.chargingStations.sockets
}

fun socket[c : ChargingSession]: one Socket {
	c.reservation.socket
}

fun payedSessions[u: User]: set ChargingSession {
	u.payments.chargingSession
}

-----------------------------------------------------------------------------------------------------
// UTILITY PREDICATES

pred reservationsOverlapping[r1: Reservation, r2: Reservation] {
	r1. from.timestamp >= r2.from.timestamp and r1.from.timestamp < r2.to.timestamp
}

// for symlicity, the range of a research here is a square and not a circle
pred nearRange[sr: StationsResearch, cs: ChargingStation] {
	((cs.position.latitude >= sr.position.latitude and 
	cs.position.latitude - sr.position.latitude <= sr.distanceRange) or
	(cs.position.latitude < sr.position.latitude and 
	sr.position.latitude - cs.position.latitude <= sr.distanceRange)) and
	((cs.position.longitude >= sr.position.longitude and
	cs.position.longitude - sr.position.longitude <= sr.distanceRange) or
	(cs.position.longitude < sr.position.longitude and
	sr.position.longitude - cs.position.longitude <= sr.distanceRange))
}

--------------------------------------------------------------------------
// FACTS

fact uniqueUsername {
	no disj u1, u2: User | u1.username = u2.username
}

fact uniqueEmail {
	no disj u1, u2: User | u1.email = u2.email
}

// password may be not unique, but all password are at least in a user
fact allPasswordsHaveUser {
	all p: Password | (some u: User | u.password = p)
}

fact allEmailAddressHaveUser {
	all e: EmailAddress | (some u: User | u.email = e)
}

fact allUsernameHaveUser {
	all usn: Username | (some u: User | u.username = usn)
}

fact noOverlappingReservationsOfUser {
	no disj r1, r2: Reservation | reservationsOverlapping[r1, r2] and
			(some u: User | r1 in u.reservations and r2 in u.reservations)
}

fact noOverlappingReservationsOnSocket {
	no disj r1, r2: Reservation | reservationsOverlapping[r1, r2] and r1.socket = r2.socket
}

fact allReservationsHaveExactlyOneUser {
	all r: Reservation | (no disj u1, u2: User | r in u1.reservations and r in u2.reservations) and
						(some usr: User | r in usr.reservations)
}

fact allStationsResearchesHaveUser {
	all sr: StationsResearch | (one u: User | sr in u.stationResearches)
}

fact stationsResarchesNearbyStations {
	all sr: StationsResearch, cs: ChargingStation | nearRange[sr, cs] implies cs in sr.nearbyStations
}

fact oneChargingSessionPerReservation {
	no disj c1, c2: ChargingSession | c1.reservation = c2.reservation
}

fact oneNotificationPerChargingSession {
	no disj n1, n2: ChargingEndedNotification | n1.chargingSession = n2.chargingSession
}

fact allChargingSessionHaveOnePayment {
	no disj p1, p2: Payment | p1.chargingSession = p2.chargingSession
}

fact paymentChargingSessionFinished {
	all pm: Payment | pm.chargingSession.isFinished = TRUE
}

fact paymentReservationSameUser {
	all u: User, pm: Payment | pm in u.payments implies pm.chargingSession.reservation in u.reservations
}

fact paymentChargingSessionSameCPO {
	all cpo: CPO, pm: Payment | 
		cpo.paymentReceiverInfo = pm.CPOInfo implies pm.chargingSession.socket in cpo.sockets
}

fact allPaymentsHaveOneUser {
	all p: Payment | (one u: User | p in u.payments)
}

fact allPaymentMethodHaveUserOrPayment {
	all pm: PaymentMethod | (some u: User | pm in u.paymentMethods) or
							(some p: Payment | p.paymentMethod = pm)
}

fact allVehicleHaveUser {
	all v: Vehicle | (some u: User | v in u.vehicles)
}

fact allCarModelHaveVehicle {
	all cm: CarModel | (some v: Vehicle | v.model = cm)
}

fact allVehicleBatteriesHaveOnlyOneVehicle {
	all vb: VehicleBattery | (one v: Vehicle | v.battery = vb)
}

fact uniqueVIN {
	no disj v1, v2: Vehicle | v1.vin = v2.vin
}

fact allNotificationsHaveUser {
	all n: Notification | (one u: User | n in u.notifications)
}

fact suggestionsVehicleOfUser {
	all usr: User, cs: ChargingSuggestion |
			(cs in usr.notifications) implies (cs.suggestedVehicle in usr.vehicles)
}

fact uniquePositionForChargingStations {
	no disj s1, s2: ChargingStation | s1.position = s2.position
}

fact oneCPOPerPaymentReceiver {
	no disj c1, c2: CPO | c1.paymentReceiverInfo = c2.paymentReceiverInfo
}

fact oneCPOPerChargingStation {
	all s: ChargingStation | (no disj c1, c2: CPO | s in c1.chargingStations and s in c2.chargingStations)
}

fact oneChargingStationPerSocket {
	all sock: Socket | (no disj s1, s2: ChargingStation | sock in s1.sockets and sock in s2.sockets)
}

fact allSocketsHaveChargingStation {
	all sock: Socket | (some cs: ChargingStation | sock in cs.sockets)
}

fact allChargingStationsHaveCPO {
	all cs: ChargingStation | (one cpo: CPO | cs in cpo.chargingStations)
}

fact allChargingSchedulePeriodHaveChargingProfile {
	all csp: ChargingSchedulePeriod | (some cp: ChargingProfile | csp in cp.schedules)
}

fact allChargingProfilesHaveSocket {
	all cp: ChargingProfile | (some sock: Socket | sock.chargingProfile = cp)
}

fact allBatteriesHaveExactlyOneChargingStation {
	all bat: ChargingStationBattery | (some cs: ChargingStation | bat in cs.batteries and
									(all cs2: ChargingStation | bat not in cs2.batteries or cs = cs2))
}

fact allDSOEnergyOfferHaveOnlyOneDSO {
	all deo: DSOEnergyOffer | (one des: DSOEnergySource | des.energyOffer = deo)
}

//Requirement: The user must insert at least a vehicle in order to receive suggestions.
fact vehicleForSuggestions {
	all cs: ChargingSuggestion, u: User | cs in u.notifications implies #u.vehicles > 0
}

//Requirement: The system shall prevent the user to make new reservations if there are unsolved payment. 
fact reservationNoUnsolvedPayment {
	all u: User | (some r: Reservation | not (some cs1: ChargingSession | cs1.reservation = r) and r in u.reservations)
				implies (all cs2: ChargingSession | cs2.reservation in u.reservations implies
													(cs2 in u.payedSessions or not cs2.isFinished = TRUE))
}

//Requirement: The system shall allow the user to have only one reservation active at the same time.
fact onlyOneActiveReservation {
	all u: User | no disj r1, r2: Reservation | r1 in u.reservations and r2 in u.reservations and 
						not (some cs1: ChargingSession | cs1.reservation = r1) and 
						not (some cs2: ChargingSession | cs2.reservation = r2)
}

--------------------------------------------------------------------------------------------------------
// ASSERTIONS

//Goal: allow users to visualize nearby charging stations
assert allowStationsResearches {
	all sr: StationsResearch | (some u: User | sr in u.stationResearches) and 
									((some cs: ChargingStation | nearRange[sr, cs]) implies
											#sr.nearbyStations > 0)
}
check allowStationsResearches for 4

// Goal: allow users to book a charge
// There might be some reservations that do not have a charging session
assert bookCharge {
	all r: Reservation | (all cs: ChargingSession | not cs.reservation = r) implies 
							(one u: User | r in u.reservations)
}
check bookCharge for 4

// Goal: allow a user to start a charging session
//(If a charging station exist, then it is started)
assert startChargingSession {
	all cs: ChargingSession | (some u: User | cs.reservation in u.reservations)
}
check startChargingSession for 4

// Goal: allow users to pay for the service
assert payForService {
	all p: Payment | p.chargingSession.isFinished = TRUE and 
					(one u: User | p in u.payments and p.chargingSession.reservation in u.reservations)
}
check payForService for 4

//Goal: allow users to receive suggestions
assert userSuggestions {
	all cs: ChargingSuggestion | (some u: User | cs in u.notifications)
}
check userSuggestions for 4

--------------------------------------------------------------------------------------------------------
// WORLDS

pred worldTest {
	#User = 1
	#Reservation = 2
	#ChargingStation = 2
	#CPO = 1
	#Payment = 1
	#ChargingStationBattery = 1
	#StationsResearch = 1
}
run worldTest for 4

pred world1 {
	#User = 4
	#CPO = 2
	#ChargingStation >= 3
	#Reservation >= 3
	#Socket >= 4
	some s: Socket | s.type = SLOW
	some s: Socket | s.type = FAST
	some s: Socket | s.type = RAPID
	#ChargingSession >= 1
	some cs: ChargingSession | cs.isFinished = TRUE
}
run world1 for 4

//This world is focused on charging suggestions
pred world2 {
	#Vehicle > 3
	#ChargingSuggestion > 3
	#User > 2
	#CPO = 1
	#Reservation = 0
}
run world2 for 6

//This world is focused on the charging points
pred world3 {
	#User = 0
	#CPO >= 2
	#ChargingStation > 4
	#ChargingStationBattery > 2
	#DSOEnergySource > 4
}
run world3 for 6

//This world is focused on the user registration
pred world4 {
	#Vehicle > 3
	#User > 2
	#CPO = 0
	some u: User | #u.vehicles > 1
	some u: User | #u.paymentMethods > 1
	#DateTime = 0
}
run world4 for 4


























