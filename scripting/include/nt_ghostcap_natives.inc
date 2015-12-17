// Double-include prevention
#if defined _ghostcap_natives_included_
	#endinput
#endif
#define _ghostcap_natives_included_

/****
		* Purpose: Tell which team capped the ghost, if either.
		*
		* @return		int	Team id of the capturing team, or 0 (team unassigned) if neither team capped.
****/
native Ghostcap_CapInfo();