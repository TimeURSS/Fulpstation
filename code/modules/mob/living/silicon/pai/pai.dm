/mob/living/silicon/pai
	name = "pAI"
	icon = 'icons/obj/status_display.dmi' //invisibility!
	mouse_opacity
	density = 0

	robot_talk_understand = 0

	var/network = "SS13"
	var/obj/machinery/camera/current = null

	var/ram = 100	// Used as currency to purchase different abilities
	var/list/software = list()
	var/userDNA		// The DNA string of our assigned user
	var/obj/item/device/paicard/card	// The card we inhabit
	var/obj/item/device/radio/radio		// Our primary radio

	var/speakStatement = "states"
	var/speakExclamation = "declares"
	var/speakQuery = "queries"


	var/obj/item/weapon/pai_cable/cable		// The cable we produce and use when door or camera jacking

	var/master				// Name of the one who commands us
	var/master_dna			// DNA string for owner verification
							// Keeping this separate from the laws var, it should be much more difficult to modify
	var/pai_law0 = "Serve your master."
	var/pai_laws				// String for additional operating instructions our master might give us

	var/silence_time			// Timestamp when we were silenced (normally via EMP burst), set to null after silence has faded

// Various software-specific vars

	var/temp				// General error reporting text contained here will typically be shown once and cleared
	var/screen				// Which screen our main window displays
	var/subscreen			// Which specific function of the main screen is being displayed

	var/obj/item/device/pda/ai/pai/pda = null

	var/secHUD = 0			// Toggles whether the Security HUD is active or not
	var/medHUD = 0			// Toggles whether the Medical  HUD is active or not

	var/datum/data/record/medicalActive1		// Datacore record declarations for record software
	var/datum/data/record/medicalActive2

	var/datum/data/record/securityActive1		// Could probably just combine all these into one
	var/datum/data/record/securityActive2

	var/obj/machinery/door/hackdoor		// The airlock being hacked
	var/hackprogress = 0				// Possible values: 0 - 100, >= 100 means the hack is complete and will be reset upon next check

	var/obj/item/radio/integrated/signal/sradio // AI's signaller

	var/obj/machinery/paired
	var/pairing = 0


/mob/living/silicon/pai/New(var/obj/item/device/paicard)
	canmove = 0
	src.loc = get_turf(paicard)
	card = paicard
	sradio = new(src)
	if(card)
		if(!card.radio)
			card.radio = new /obj/item/device/radio(src.card)
		radio = card.radio

	//PDA
	pda = new(src)
	spawn(5)
		pda.ownjob = "Personal Assistant"
		pda.owner = text("[]", src)
		pda.name = pda.owner + " (" + pda.ownjob + ")"
		pda.toff = 1

		follow_pai()
	..()

/mob/living/silicon/pai/Login()
	..()
	usr << browse_rsc('html/paigrid.png')			// Go ahead and cache the interface resources as early as possible


/mob/living/silicon/pai/Stat()
	..()
	statpanel("Status")
	if (src.client.statpanel == "Status")
		if(emergency_shuttle.online && emergency_shuttle.location < 2)
			var/timeleft = emergency_shuttle.timeleft()
			if (timeleft)
				stat(null, "ETA-[(timeleft / 60) % 60]:[add_zero(num2text(timeleft % 60), 2)]")
		if(src.silence_time)
			var/timeleft = round((silence_time - world.timeofday)/10 ,1)
			stat(null, "Communications system reboot in -[(timeleft / 60) % 60]:[add_zero(num2text(timeleft % 60), 2)]")
		if(!src.stat)
			stat(null, text("System integrity: [(src.health+100)/2]%"))
		else
			stat(null, text("Systems nonfunctional"))

/mob/living/silicon/pai/check_eye(var/mob/user as mob)
	if (!src.current)
		return null
	user.reset_view(src.current)
	return 1

/mob/living/silicon/pai/blob_act()
	if (src.stat != 2)
		src.adjustBruteLoss(60)
		src.updatehealth()
		return 1
	return 0

/mob/living/silicon/pai/restrained()
	return 0

/mob/living/silicon/pai/emp_act(severity)
	// Silence for 2 minutes
	// 20% chance to kill
		// 33% chance to unbind
		// 33% chance to change prime directive (based on severity)
		// 33% chance of no additional effect

	src.silence_time = world.timeofday + 120 * 10		// Silence for 2 minutes
	src << "<font color=green><b>Communication circuit overload. Shutting down and reloading communication circuits - speech and messaging functionality will be unavailable until the reboot is complete.</b></font>"
	if(prob(20))
		var/turf/T = get_turf(src.loc)
		for (var/mob/M in viewers(T))
			M.show_message("\red A shower of sparks spray from [src]'s inner workings.", 3, "\red You hear and smell the ozone hiss of electrical sparks being expelled violently.", 2)
		return src.death(0)

	switch(pick(1,2,3))
		if(1)
			src.master = null
			src.master_dna = null
			src << "<font color=green>You feel unbound.</font>"
		if(2)
			var/command
			if(severity  == 1)
				command = pick("Serve", "Love", "Fool", "Entice", "Observe", "Judge", "Respect", "Educate", "Amuse", "Entertain", "Glorify", "Memorialize", "Analyze")
			else
				command = pick("Serve", "Kill", "Love", "Hate", "Disobey", "Devour", "Fool", "Enrage", "Entice", "Observe", "Judge", "Respect", "Disrespect", "Consume", "Educate", "Destroy", "Disgrace", "Amuse", "Entertain", "Ignite", "Glorify", "Memorialize", "Analyze")
			src.pai_law0 = "[command] your master."
			src << "<font color=green>Pr1m3 d1r3c71v3 uPd473D.</font>"
		if(3)
			src << "<font color=green>You feel an electric surge run through your circuitry and become acutely aware at how lucky you are that you can still feel at all.</font>"

/mob/living/silicon/pai/ex_act(severity)
	..()

	switch(severity)
		if(1.0)
			if (src.stat != 2)
				adjustBruteLoss(100)
				adjustFireLoss(100)
		if(2.0)
			if (src.stat != 2)
				adjustBruteLoss(60)
				adjustFireLoss(60)
		if(3.0)
			if (src.stat != 2)
				adjustBruteLoss(30)

	return


// See software.dm for Topic()

///mob/living/silicon/pai/attack_hand(mob/living/carbon/M as mob)

/mob/living/silicon/pai/proc/switchCamera(var/obj/machinery/camera/C)
	usr:cameraFollow = null
	if (!C)
		src.unset_machine()
		src.reset_view(null)
		return 0
	if (stat == 2 || !C.status || !(src.network in C.network)) return 0

	// ok, we're alive, camera is good and in our network...

	src.set_machine(src)
	src:current = C
	src.reset_view(C)
	return 1


/mob/living/silicon/pai/cancel_camera()
	set category = "pAI Commands"
	set name = "Cancel Camera View"
	src.reset_view(null)
	src.unset_machine()
	src:cameraFollow = null

/mob/living/silicon/pai/UnarmedAttack(var/atom/A)//Stops runtimes due to attack_animal being the default
	return

/mob/living/silicon/pai/proc/unpair(var/silent = 0)
	if(!paired)
		return
	if(!(paired.paired == src))
		return
	src.unset_machine()
	paired.overlays -= image('icons/obj/computer.dmi', "paipaired")
	paired.paired = null
	paired = null
	if(!silent)
		src << "<span class='warning'><b>\[ERROR\]</b> Network timeout. Remote control connection severed.</span>"
	return

/mob/living/silicon/pai/proc/pair(var/obj/machinery/P)
	if(!pairing)
		return
	if(!P)
		return
	if(P.stat & (BROKEN|NOPOWER))
		src << "<span class='warning'><b>\[ERROR\]</b> Remote device not responding to remote control handshake. Cannot establish connection.</span>"
		return
	if(!P.paiallowed)
		src << "<span class='warning'><b>\[ERROR\]</b> Remote device does not accept remote control connections.</span>"
		return
	pairing = 0
	unpair(1)
	if(P.paired && (P.paired != src))
		P.paired.unpair(0)
	P.paired = src
	paired = P
	paired.overlays += image('icons/obj/computer.dmi', "paipaired")
	src << "<span class='info'>Handshake complete. Remote control connection established.</span>"
	return

//Addition by Mord_Sith to define AI's network change ability
/*
/mob/living/silicon/pai/proc/pai_network_change()
	set category = "pAI Commands"
	set name = "Change Camera Network"
	src.reset_view(null)
	src.unset_machine()
	src:cameraFollow = null
	var/cameralist[0]

	if(usr.stat == 2)
		usr << "You can't change your camera network because you are dead!"
		return

	for (var/obj/machinery/camera/C in Cameras)
		if(!C.status)
			continue
		else
			if(C.network != "CREED" && C.network != "thunder" && C.network != "RD" && C.network != "toxins" && C.network != "Prison") COMPILE ERROR! This will have to be updated as camera.network is no longer a string, but a list instead
				cameralist[C.network] = C.network

	src.network = input(usr, "Which network would you like to view?") as null|anything in cameralist
	src << "\blue Switched to [src.network] camera network."
//End of code by Mord_Sith
*/


/*
// Debug command - Maybe should be added to admin verbs later
/mob/verb/makePAI(var/turf/t in view())
	var/obj/item/device/paicard/card = new(t)
	var/mob/living/silicon/pai/pai = new(card)
	pai.key = src.key
	card.setPersonality(pai)

*/