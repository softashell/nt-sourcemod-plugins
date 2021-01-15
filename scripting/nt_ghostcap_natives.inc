#if defined _NT_GHOSTCAP_NATIVES_INC_
	#endinput
#else
#define _NT_GHOSTCAP_NATIVES_INC_
#endif

/**
 * Removes a capzone from this plugin's tracking entirely, as if it was removed.
 * This can be useful to call before dynamically deleting a capzone, to avoid plugin conflicts.
 * Note that either return value may not be an error, but merely a side effect
 * of the plugin load order.
 *
 * @param capzone_entity    Integer value of a valid capzone entity index.
 * @return        			1 if capzone was recognized and hence removed from this plugin's tracking. 0 otherwise.
 */
native int GhostEvents_RemoveCapzone(int capzone_entity);

/**
 * Updates capzone positions info, etc, for a capzone tracked by this plugin.
 * This can be useful after dynamically moving a capzone to a different position or changing its radius.
 * Note that either return value may not be an error, but merely a side effect
 * of the plugin load order.
 *
 * @param capzone_entity    Integer value of a valid capzone entity index.
 * @return        			1 if capzone was recognized, and it was also successfully updated in this plugin's tracking. 0 otherwise.
 */
native int GhostEvents_UpdateCapzone(int capzone_entity);
