# dialog_tracker.gd
extends Node

# Dictionary to track dialog stages for each NPC
var npc_dialog_stages = {}

# Get current dialog stage for an NPC
func get_dialog_stage(npc_id: String) -> int:
	if npc_dialog_stages.has(npc_id):
		return npc_dialog_stages[npc_id]
	else:
		return 0  # Default stage is 0 (first encounter)

# Advance dialog stage for an NPC
func advance_dialog_stage(npc_id: String, new_stage = -1) -> void:
	var current_stage = get_dialog_stage(npc_id)
	
	# If new_stage is -1, just increment by 1
	if new_stage == -1:
		npc_dialog_stages[npc_id] = current_stage + 1
	# Otherwise set to the specified stage
	else:
		npc_dialog_stages[npc_id] = new_stage
	
	print("Advanced dialog stage for " + npc_id + " to " + str(npc_dialog_stages[npc_id]))

# Reset dialog progress for testing
func reset_all_progress() -> void:
	npc_dialog_stages.clear()
	print("All dialog progress reset")

# Reset specific NPC progress
func reset_npc_progress(npc_id: String) -> void:
	if npc_dialog_stages.has(npc_id):
		npc_dialog_stages.erase(npc_id)
		print("Dialog progress for " + npc_id + " has been reset")
