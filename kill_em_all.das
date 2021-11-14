require daslib/media
options debugger            // uncomment for debug in VS Code
require daslib/debug        // uncomment for debug in VS Code
require math

enum GUN_TYPE
    PISTOL
    MACHINE_GUN

enum MONSTER_TYPE :int
    ZOMBIE
    RUNNER
    TANK
    TOTAL

struct PLAYER
    pos: int2
    size: int
    color: uint

struct GUN
    id: GUN_TYPE
    pos: int2
    size: float2
    color: uint
    angle: float
    fire_delay :float

struct BULLET
    pos: float2
    speed: float2
    color: uint
    ttl: float
    len: float
    delay: float
    damage: int

struct MONSTER
    pos: float2
    speed: float2
    color: uint
    hp: int
    origHp: int
    size: float2

var
    player: PLAYER
    currentGun: GUN
    acceleration: float = 300f
    seed: int4
    spawnCooldown: float = 2f
    spawnTime: float
    isEnd: bool = false
    killedCount: int
    deadCount: int = 0

    bullets: array<BULLET>
    monsters: array<MONSTER>



//------------ player ---------------------
def init_player(var p: PLAYER)
    p.size = 30
    p.pos = int2(get_screen_width() / 2, get_screen_height() / 2)
    p.color = make_color(0.4, 0.45, 1.0)

def render_player(var p: PLAYER)
    fill_circle(int(p.pos.x), int(p.pos.y), p.size, p.color)

//------------ guns ----------------------
def init_pistol()
    return [[GUN
        id = GUN_TYPE PISTOL,
        size = float2(20f, 10f),
        color = make_color(1f, 1f, 1f)
    ]]

def init_machine_gun()
    return [[GUN
        id = GUN_TYPE MACHINE_GUN,
        size = float2(20f, 10f),
        color = make_color(1f, 0.7f, 0.7f)
    ]]

def gun_angle(var pos: int2): float
    let l = get_mouse_position() - float2(pos)
    return atan2(l.y, l.x)

def calc_gun_pos(var g: GUN; var p: PLAYER)
    let angle = gun_angle(p.pos)
    g.pos.x = p.pos.x + int(cos(angle) * float(p.size))
    g.pos.y = p.pos.y + int(sin(angle) * float(p.size))

def render_gun(var g: GUN; var p: PLAYER)
    line(p.pos.x, p.pos.y, g.pos.x, g.pos.y, g.color)

def update_gun_data(var g :GUN; var p :PLAYER; dt :float)
    calc_gun_pos(g, p)
    g.fire_delay -= dt
    if (g.fire_delay < 0f)
        g.fire_delay = 0f

//-------------- utils ------------------
def move(deltaX :int; deltaY :int)
    player.pos.x += deltaX
    player.pos.x = min(get_screen_width() - player.size, max(player.size, player.pos.x))
    player.pos.y += deltaY
    player.pos.y = min(get_screen_height() - player.size, max(player.size, player.pos.y))

def select_weapon(numKey :GUN_TYPE)
    clear(bullets)
    if (numKey == GUN_TYPE PISTOL)
        currentGun = init_pistol()
    if (numKey == GUN_TYPE MACHINE_GUN)
        currentGun = init_machine_gun()

//-------------- bullet ----------------
def init_pistol_bullet(g :GUN) :BULLET
    let angle = gun_angle(g.pos)
    let posX = g.pos.x + int(cos(angle))
    let posY = g.pos.y + int(sin(angle))

    return [[ BULLET
        pos = float2(posX, posY),
        speed = float2(cos(angle), sin(angle)) * float2(600f),
        color = make_color(1f, 0f, 0f),
        ttl = 0.5f,
        delay = 0.75f,
        len = 0.005,
        damage = 5
    ]]

def init_machine_gun_bullet(g :GUN) :BULLET
    let angle = gun_angle(g.pos)
    let posX = g.pos.x + int(cos(angle))
    let posY = g.pos.y + int(sin(angle))

    return [[ BULLET
        pos = float2(posX, posY),
        speed = float2(cos(angle), sin(angle)) * float2(1200f),
        color = make_color(1f, 1f, 0f),
        ttl = 1f,
        delay = 0.15f,
        len = 0.002,
        damage = 1
    ]]

def shoot(var g :GUN)
    if (g.id == GUN_TYPE PISTOL)
        var b = init_pistol_bullet(g)
        if g.fire_delay <= 0f
            g.fire_delay = b.delay
            push(bullets, b)

    if (g.id == GUN_TYPE MACHINE_GUN)
        var b = init_machine_gun_bullet(g)
        if g.fire_delay <= 0f
            g.fire_delay = b.delay
            push(bullets, b)

def render_bullet(var b :BULLET)
    for dx in range(-1, 2)
        for dy in range(-1, 2)
            let p1 = b.pos + b.speed * b.len
            let p2 = b.pos - b.speed * b.len
            line(p1.x + float(dx * get_screen_width()),
                 p1.y + float(dy * get_screen_height()),
                 p2.x + float(dx * get_screen_width()),
                 p2.y + float(dy * get_screen_height()),
                 b.color)


def render_bullets()
    for b in bullets
        render_bullet(b)

def need_stop_bullet(var b :BULLET) :bool
    return b.ttl < 0.0 || b.pos.x < 0.0 || b.pos.x > float(get_screen_width()) || b.pos.y < 0.0 || b.pos.y > float(get_screen_height())

def update_bullets_data(dt :float)
    var idx = length(bullets) - 1
    while idx >= 0
        bullets[idx].pos += bullets[idx].speed * dt
        bullets[idx].ttl -= dt

        for m in monsters
            if bullets[idx] |> isBulletIntersect(m)
                change_monster_hp(m, -1 * bullets[idx].damage)
                erase(bullets, idx)
                idx--
                break

        if idx >= 0 && need_stop_bullet(bullets[idx])
            erase(bullets, idx)
        idx--

//------------- monster --------------

def init_monster(var hp :int; var size :float2; var speed :float2)
    var rndSide = random_int(seed) % 4
    var pos :float2

    if rndSide == 0
        pos = float2(-1f * size.x, float(random_int(seed) % get_screen_height()))
    if rndSide == 1
        pos = float2(float(random_int(seed) % get_screen_width()), -1f * size.y)
    if rndSide == 2
        pos = float2(size.x + float(get_screen_width()), float(random_int(seed) % get_screen_height()))
    if rndSide == 3
        pos = float2(float(random_int(seed) % get_screen_width()), size.y + float(get_screen_height()))

    print("{rndSide}\n")
    return [[MONSTER
        pos = pos,
        origHp = hp,
        hp = hp,
        size = size,
        speed = speed
    ]]

def init_zombie() :MONSTER
    return init_monster(10, float2(20, 20), float2(0.05))

def init_runner() :MONSTER
    return init_monster(5, float2(10, 10), float2(0.2))

def init_tank() :MONSTER
    return init_monster(30, float2(40, 40), float2(0.01))

def need_spawn() :bool
    return spawnTime <= 0f

def spawn_monsters()
    if (!need_spawn())
        return

    spawnTime = spawnCooldown
    var rndType = random_int(seed) % int(MONSTER_TYPE TOTAL)
    if (rndType == int(MONSTER_TYPE ZOMBIE))
        push(monsters, init_zombie())
    if (rndType == int(MONSTER_TYPE RUNNER))
        push(monsters, init_runner())
    if (rndType == int(MONSTER_TYPE TANK))
        push(monsters, init_tank())

def make_monster_color(var m :MONSTER) :uint
    var percent = (float(m.hp) / float(m.origHp))
    var g = 0.0
    var b = 1.0
    if (percent >= 0.5)
        b -= (1.0 - percent) * 2.0
        g = 1.0
    if (percent < 0.5)
        b = 0.0
        g += percent * 2.0

    return make_color(1.0, g, b)

def monster_angle(var m: MONSTER): float
    let l = m.pos - float2(player.pos)
    return atan2(l.y, l.x)

def calc_monster_pos(var m: MONSTER)
    let angle = monster_angle(m)
    m.pos.x = m.pos.x - cos(angle) * m.speed.x * m.size.x
    m.pos.y = m.pos.y - sin(angle) * m.speed.y * m.size.y

def kill_monster(var idx :int)
    erase(monsters, idx)
    killedCount++

def update_monsters_data(dt :float)
    spawnTime -= dt
    var idx = length(monsters) -1
    while idx >= 0
        monsters[idx].color = make_monster_color(monsters[idx])
        calc_monster_pos(monsters[idx])
        if (player |> isMonsterIntersect(monsters[idx]))
            isEnd = true
            break

        if (monsters[idx].hp <= 0)
            kill_monster(idx)

        idx--

def render_monster(var m :MONSTER)
    rect(int(m.pos.x),
        int(m.pos.y),
        int(m.size.x),
        int(m.size.y),
        m.color)

def render_monsters()
    for m in monsters
        render_monster(m)

def change_monster_hp(var m :MONSTER; delta :int)
    m.hp += delta
    if m.hp >= m.origHp
        m.hp = m.origHp
    if m.hp <= 0
        m.hp = 0

//-------------- intersection ---------------
def dist_wrapped(a: float2; b: float2) :float
    var res = 1000000.f
    for dx in range(-1, 2)
        for dy in range(-1, 2)
            let d = length(a - b + float2(float(dx * get_screen_width()), float(dx * get_screen_height())))
            if d < res
                res = d
    return res

def isMonsterIntersect(var p :PLAYER; var m :MONSTER) :bool
    var dist = dist_wrapped(m.pos, float2(p.pos))
    return dist < (float(p.size) + min(m.size.x, m.size.y))

def isBulletIntersect(var b :BULLET; var m :MONSTER) :bool
    var dist = dist_wrapped(b.pos, m.pos)
    return dist < (b.len + min(m.size.x, m.size.y))

def reset_game()
    isEnd = false
    killedCount = 0
    init_player(player)
    clear(monsters)

// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize
    set_resolution(get_desktop_width() / 2, get_desktop_height() / 2)
    set_antialiasing(4)
    randomize_seed(seed)
    select_weapon(GUN_TYPE PISTOL)
    reset_game()
    return

// this function is called to update game data,
// dt - time elapsed since the previous update (in seconds)
[export]
def act(dt: float)
    var killed = ""
    if killedCount > 0
        killed = "Killed: {killedCount}. "

    var dead = ""
    if (deadCount > 0)
        dead = "Dead: {deadCount}. "

    set_window_title("Kill'em all. {dead}{killed}Up/W; Down/S; Left/A; Right/D, Left mouse/space - shoot, 1 - pistol, 2 - machine gun")

    if isEnd
        deadCount++
        reset_game()

    if get_key(VK_ESCAPE)
        schedule_quit_game()

    if (get_key(VK_1))
        select_weapon(GUN_TYPE PISTOL)
    if (get_key(VK_2))
        select_weapon(GUN_TYPE MACHINE_GUN)

    var delta = int(dt * acceleration)
    if (get_key(VK_UP) || get_key(VK_W))
        move(0, -1 * delta)
    if (get_key(VK_DOWN) || get_key(VK_S))
        move(0, delta)
    if (get_key(VK_RIGHT) || get_key(VK_D))
        move(delta, 0)
    if (get_key(VK_LEFT) || get_key(VK_A))
        move(-1 * delta, 0)

    if (get_mouse_button(MB_LEFT) || get_key(VK_SPACE))
        currentGun |> shoot()

    currentGun |> update_gun_data(player, dt)
    update_bullets_data(dt)
    spawn_monsters()
    update_monsters_data(dt)
    return

// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    player |> render_player()
    currentGun |> render_gun(player)
    render_bullets()
    render_monsters()
    return