class_name Combat
extends RefCounted
## Deterministic abstract combat resolution. Rolls are supplied by the caller
## (drawn from the game's seeded RNG) so results are reproducible.

## Resolve an attack of attack_divisions against defense_divisions in a
## territory with the given terrain defense multiplier.
## atk_roll / def_roll: floats in a small band around 1.0 (e.g. 0.85..1.15).
## Returns a dictionary: {captured, attacker_losses, defender_losses, survivors}.
static func resolve(attack_divisions: int, defense_divisions: int, terrain_defense: float, atk_roll: float, def_roll: float) -> Dictionary:
	if attack_divisions <= 0:
		return {"captured": false, "attacker_losses": 0, "defender_losses": 0, "survivors": 0}

	var atk_power: float = float(attack_divisions) * atk_roll
	var def_power: float = float(defense_divisions) * terrain_defense * def_roll

	if atk_power > def_power:
		var ratio: float = def_power / atk_power
		var losses := int(ceil(float(attack_divisions) * ratio * 0.5))
		losses = clampi(losses, 0, attack_divisions - 1)
		return {
			"captured": true,
			"attacker_losses": losses,
			"defender_losses": defense_divisions,
			"survivors": attack_divisions - losses,
		}

	var ratio2: float = atk_power / max(1.0, def_power)
	var def_losses := int(ceil(float(defense_divisions) * ratio2 * 0.5))
	def_losses = clampi(def_losses, 0, defense_divisions)
	var atk_losses := int(ceil(float(attack_divisions) * 0.6))
	atk_losses = clampi(atk_losses, 0, attack_divisions)
	return {
		"captured": false,
		"attacker_losses": atk_losses,
		"defender_losses": def_losses,
		"survivors": attack_divisions - atk_losses,
	}
