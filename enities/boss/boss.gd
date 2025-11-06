# Boss.gd
extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D

var boss_id: int = -1
var boss_type: String = "final_boss"
var current_phase: int = 1

# Señales para el boss
signal boss_phase_changed(phase)
signal boss_died()
signal boss_attacked(target_id, damage)
signal boss_health_updated(hp, max_hp)

func _ready():
    print("👹 BOSS INICIALIZADO - ID:", boss_id, " Tipo:", boss_type)
    # Configurar animaciones por defecto
    if animated_sprite:
        animated_sprite.play("idle")

func set_boss_id(id: int):
    boss_id = id
    name = "Boss_" + str(id)

func set_boss_type(type: String):
    boss_type = type

func set_patrol_center(center: Vector2):
    # Implementar si es necesario
    pass

func update_hp(hp: int):
    # Actualizar barra de vida si existe
    var health_bar = get_node_or_null("HealthBar")
    if health_bar and health_bar.has_method("update_health"):
        health_bar.update_health(hp, 1000) # Asumiendo 1000 de vida máxima

func play_animation(anim_name: String):
    if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
        animated_sprite.play(anim_name)
        print("🎭 BOSS ANIMACIÓN:", anim_name)
    elif animated_sprite:
        # Si no existe la animación, al menos intentar reproducir algo
        if animated_sprite.sprite_frames and animated_sprite.sprite_frames.get_animation_names().size() > 0:
            var default_anim = animated_sprite.sprite_frames.get_animation_names()[0]
            animated_sprite.play(default_anim)
        else:
            print("❌ NO HAY ANIMACIONES DISPONIBLES para el boss")
    else:
        print("❌ ANIMATED_SPRITE NO ENCONTRADO en el boss")

func _transition_to_phase(phase: int):
    current_phase = phase
    print("🔥 BOSS CAMBIA A FASE:", phase)
    
    # Efectos visuales para cambio de fase
    match phase:
        2:
            # Fase 2 - cambiar color a naranja
            modulate = Color(1.0, 0.6, 0.3)
            play_animation("phase_transition")
        3:
            # Fase 3 - cambiar color a rojo
            modulate = Color(1.0, 0.3, 0.2)
            play_animation("phase_transition_rage")
    
    emit_signal("boss_phase_changed", phase)

func get_enemy_type() -> String:
    return boss_type