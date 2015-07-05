// This file is distributed under the terms of the MIT Licece (see the LICENSE
// file).

import 'dart:html';
import 'dart:async';

class GridPoint {
    final int x, y;
    GridPoint(this.x, this.y);

    GridPoint.fromDirection(GridPoint p, List<int> m)
        : x = p.x + m[0],
          y = p.y + m[1];

    bool operator ==(p) {
        return (p is GridPoint) && (p.x == x) && (p.y == y);
    }

    String toString() {
        return "GridPont(" + x.toString() + "," + y.toString() + ")";
    }

    int get hashCode {
        return (x + y);
    }

    int distance(GridPoint p) {
        return (this.x - p.x).abs() + (this.y - p.y).abs();
    }
}

void prGridPoint(p) {
    if (p == null)
        print(p);
    else if (p is GridPoint)
        print([p.x,p.y]);
    else assert(false);
}

enum Action_ { Invalid, Move, Attack, Wait}

class MoveAction extends Action {
    GridPoint dest;
    MoveAction._internal(this.dest) : super._internal(Action_.Move);

    String toString() {
        return "MoveAction to " + dest.toString();
    }
}

class WaitAction extends Action {

    WaitAction._internal() : super._internal(Action_.Wait);

    String toString() {
        return "WaitAction";
    }
}

class AttackAction extends Action {
    GridPoint target;

    AttackAction._internal(this.target): super._internal(Action_.Attack);

    String toString() {
        return "AttackAction to " + target.toString();
    }
}

abstract class Action {
    Action_ type;

    Action._internal(this.type); // internal constructor

    static Action newAttackAction(GridPoint target) {
        return new AttackAction._internal(target);
    }

    AttackAction asAttack() {
        assert(this.type == Action_.Attack);
        return this as AttackAction;
    }

    static Action newMoveAction(GridPoint dest) {
        return new MoveAction._internal(dest);
    }

    MoveAction asMove() {
        assert(this.type == Action_.Move);
        return this as MoveAction;
    }

    static Action newWaitAction() {
        return new WaitAction._internal();
    }

    WaitAction asWait() {
        assert(this.type == Action_.Wait);
        return this as WaitAction;
    }
}

const int DrawNormal = 0;
const int DrawHit    = 1;

abstract class Occupant {
    GridPoint location; // location if on grid, or null
    DungeonState ds;
    bool hit;

    Occupant(this.ds) : location = null, hit = false;

    void drawOnCell(CanvasRenderingContext2D ctx,
                    num bx0, num by0, num bxlen, num bylen);
}

abstract class Monster extends Occupant {
    Monster(DungeonState ds) : super(ds);
    Action takeTurn();
}

class Zombie extends Monster {

    // zombies act every other turn
    bool active;

    Zombie(DungeonState ds, this.active): super(ds);

    Action takeTurn() {
        if (active) {
            active = false;
            return takeTurnActive();
        } else {
            active = true;
            return Action.newWaitAction();
        }
    }

    Action takeTurnActive() {
        Grid g = ds.dg.grid;
        Hero hero = ds.hero;
        assert(location != null && hero.location != null);

        // find next point to move or attack
        var point = g.neighbors(location).where( (p) {
                // filter occupied points (unless occupied by hero)
                Square s = g.getSquare(p);
                return (s.occupant == null || s.occupant == hero);
            }).fold(null, (prevp, newp) {
                // find the point with minimum distance to hero
                var dst = hero.location;
                if (prevp == null || prevp.distance(dst) > newp.distance(dst)) {
                    return newp;
                } else {
                    return prevp;
                }
            });

        var action;
        if (point.distance(hero.location) == 0) {
            action = Action.newAttackAction(point);
        } else {
            action = Action.newMoveAction(point);
        }

        return action;
    }

    void drawOnCell(CanvasRenderingContext2D ctx,
                      num bx0, num by0, num bxlen, num bylen) {

        var x = bx0 + bxlen/2;
        var y = by0 + bylen/2;

        if (hit) {
            ctx.fillStyle = "#cd0000";
        } else if (active) {
            ctx.fillStyle = "black";
        } else {
            ctx.fillStyle = "gray";
        }
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.font = "37pt Calibri";
        ctx.fillText("z", x, y);
    }

    void toString() { return "Zombie";}
}


// NB: Hero is probably the wrong name for this
// (see, for example, http://www.roguelikeradio.com/2013/08/episode-77-hero-trap.html)
class Hero extends Occupant {

    Hero(DungeonState ds) : super(ds);

    // draw "Hero" on a bounding box
    void drawOnCell(CanvasRenderingContext2D ctx,
                      num bx0, num by0, num bxlen, num bylen) {
        //window.console.debug("hero: drawOnCell()");
        var x = bx0 + bxlen/2;
        var y = by0 + bylen/2;

        if (hit) {
            ctx.fillStyle = "#cd0000";
        } else {
            ctx.fillStyle = "black";
        }
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.font = "37pt Calibri";
        ctx.fillText("@", x, y);
    }

    void toString() { return "Character";}
}


// a grid square
class Square {
    Occupant occupant; // an occupant or NULL

    Square() : occupant = null;

    bool isOccupied() {
        return occupant != null;
    }

    bool isEmpty() {
        return !isOccupied();
    }

    String toString() {
        return occupant.toString();
    }
}

enum Input {
    Up, Down, Left, Right
}

// A dungeon grid
enum Move { Up /* 0 */, Down, Left, Right, }
class Grid {
    static const up    = const  [ 0,-1];
    static const down  = const  [ 0, 1];
    static const left  = const  [-1, 0];
    static const right = const  [ 1, 0];
    static const directions = const  [up,down,left,right];

    final int x, y;
    List<Square> squares;

    Grid(this.x, this.y) {
        squares = new List<Square>.generate(x*y, (int _) => new Square());
    }

    Square getSquare(GridPoint p) {
        return squares[p.y*x + p.x];
    }

    // check if a point is within the bounds of the grid
    bool validPoint(GridPoint p) {
        return (p.x >= 0 && p.x < x && p.y >= 0 && p.y < y);
    }

    Iterable<GridPoint> neighbors(GridPoint p) {
        return directions.map((d) => new GridPoint.fromDirection(p,d))
                         .where(validPoint);
    }

    void placeOnSquare(GridPoint p, Occupant o) {
        Square s = getSquare(p);
        assert(s.isEmpty());
        s.occupant = o;
        o.location = p;
    }

    bool moveToPoint(Occupant o, GridPoint newp) {
        GridPoint oldp = o.location;
        if (oldp == null) {
            window.console.debug("moveToPoint: occupant does not have a location!\n");
            return false;
        }

        Square olds = getSquare(oldp);
        Square news = getSquare(newp);
        assert(olds.occupant == o);

        if (news.occupant != null) {
            //window.console.debug("new square occupied\n");
            return false;
        }

        news.occupant = o;
        o.location = newp;
        olds.occupant = null;
        return true;
    }

    // returns new point or null if move was not possible
    bool moveOccupant(Occupant o, GridPoint newp) {

        GridPoint oldp = o.location;
        if (oldp == null) {
            window.console.debug("moveOccupant: occupant does not have a location!\n");
            return null;
        }

        Square olds = getSquare(oldp);
        Square news = getSquare(newp);
        assert(olds.occupant == o);

        if (news.occupant != null) {
            //window.console.debug("new square occupied\n");
            return false;
        }

        news.occupant = o;
        o.location = newp;
        olds.occupant = null;
        return true;
    }

    void removeOccupant(Occupant o) {
        Square s = getSquare(o.location);
        s.occupant = null;
    }
}

class StatusConsole {

    static const bgColor = "white";
    static const lnColor = "black";
    static const lnWidth = 2;

    num real_x, real_y, real_xsize, real_ysize; // including border
    num x, y, xsize, ysize; // for text
    List<String> lines;

    StatusConsole(this.real_x, this.real_y, this.real_xsize, this.real_ysize) {
        this.lines = [];
        this.x = this.real_x + lnWidth;
        this.y = this.real_y + lnWidth;
        this.xsize = real_xsize - 2*lnWidth;
        this.ysize = real_ysize - 2*lnWidth;
    }

    void drawStatus(CanvasRenderingContext2D ctx) {
        ctx.fillStyle = lnColor;
        ctx.fillRect(real_x, real_y, real_xsize, real_ysize);

        ctx.fillStyle = bgColor;
        ctx.fillRect(x, y, xsize, ysize);
    }

    void updateStatus(CanvasRenderingContext2D ctx, String line) {

        if (line != null) {
            // line = lines.length.toString() + ": " + line;
            this.lines.add(line);
        }

        var nlines = 0;
        var nheight = 0;
        const textOffset = 10;
        var yTextSize = this.ysize -(2*textOffset);
        var yText     = this.y + textOffset;
        // const tFont   = "12pt Calibri";
        const tHeight = 16;

        // TODO: since he have hardcoded lineHeight (some metrics are not
        // supported in firefox, and I'm not sure I got their meaning right even
        // for chrome), the code below can be simplified.

        for (var l=lines.length - 1; l >= 0; l--) {
            // var metric = ctx.measureText(lines[l]);
            // var lineHeight = metric.actualBoundingBoxDescent - metric.actualBoundingBoxAscent;
            var lineHeight = tHeight;
            // window.console.debug("line:" + l.toString() + "text:" + lines[l] + "lineHeight: " + lineHeight.toString() + " nheight:" + nheight.toString());
            if (lineHeight + nheight > yTextSize)
                break;

            nheight += lineHeight;
            nlines  += 1;
        }

        var lstart = lines.length - nlines;
        var h = yText;
        // window.console.debug("lstart: " + lstart.toString() + " nlines:" + nlines.toString());

        ctx.fillStyle = "white";
        ctx.fillRect(this.x, this.y, this.xsize, this.ysize);

        ctx.font = "12pt Calibri";
        ctx.textAlign = "left";
        ctx.textBaseline = "top";
        ctx.fillStyle = "black";
        for (var i=0; i<nlines; i++) {
            var l = lstart + i;
            ctx.fillText(lines[l], this.x + textOffset, h);
            //var metric = ctx.measureText(lines[l]);
            // var lineHeight = metric.actualBoundingBoxDescent - metric.actualBoundingBoxAscent;
            var lineHeight = tHeight;
            h += lineHeight;
        }
    }
}

class DrawnGrid {
    static const boxColor      = '#f0f0f0';
    static const boxLineColor  = '#676767';
    static const boxBorderSize = 6;
    static const hlColor       = 'rgba(32,32,2,.1)';
    static const statusSize    = 400;

    Grid grid;
    num xsize, ysize, real_xsize;
    CanvasRenderingContext2D ctx;

    num stepSizeX, stepSizeY;
    num boxDimX, boxDimY;

    StatusConsole status;

    bool paused;

    DrawnGrid(this.grid, this.real_xsize, this.ysize, this.ctx) {
        this.xsize = this.real_xsize - statusSize;
        stepSizeX = ((xsize - boxBorderSize) / grid.x);
        stepSizeY = ((ysize - boxBorderSize) / grid.y);
        boxDimX = stepSizeX - boxBorderSize;
        boxDimY = stepSizeY - boxBorderSize;
        this.status = new StatusConsole(
                            this.xsize + 10, 0,
                            this.real_xsize - this.xsize - 10, this.ysize);
    }

    GridPoint getGridCoords(num x, num y) {
        var gx = x / stepSizeX;
        var ox = x % stepSizeX;
        if (gx >= grid.x || ox <= boxBorderSize)
            return null;

        var gy = y / stepSizeY;
        var oy = y % stepSizeY;
        if (gy >= grid.y || oy <= boxBorderSize)
            return null;

        return new GridPoint(gx.floor(), gy.floor());
    }

    void drawGrid() {
        // background (borders)
        ctx.fillStyle = boxLineColor;
        ctx.fillRect(0, 0, xsize, ysize);
        // boxes
        ctx.fillStyle = boxColor;
        for (var x = boxBorderSize; x < xsize; x += stepSizeX)
            for (var y = boxBorderSize; y < ysize; y += stepSizeY)
                ctx.fillRect(x, y, boxDimX, boxDimY);

        status.drawStatus(ctx);
    }

    void drawGridSquare(GridPoint p) {
        ctx.fillStyle = boxColor;
        var x = boxBorderSize + (p.x*stepSizeX);
        var y = boxBorderSize + (p.y*stepSizeY);
        ctx.fillRect(x, y, boxDimX, boxDimY);
        //window.console.debug("draw square: " + p.toString());

        var sq = grid.getSquare(p);
        if (sq.isOccupied()) {
            //window.console.debug("draw cell");
            sq.occupant.drawOnCell(ctx, x, y, boxDimX, boxDimX);
        }
    }

    void placeOnSquare(GridPoint p, Occupant o) {
        grid.placeOnSquare(p, o);
        drawGridSquare(p);
    }

    bool moveOccupant(Occupant o, GridPoint newp) {
        GridPoint oldp = o.location;
        if (newp == null) {
            return false;
        }

        if (!grid.moveOccupant(o, newp)) {
            return false;
        }

        drawGridSquare(oldp);
        drawGridSquare(newp);
        return true;

    }

    void hitOccupant(Occupant o) {
        o.hit = true;
        drawGridSquare(o.location);
        new Future.delayed(const Duration(milliseconds: 150), () {
            o.hit = false;
            drawGridSquare(o.location);
        });
    }

    void removeOccupant(Occupant o) {
        grid.removeOccupant(o);
    }

    void pause() {
        if (this.paused)
            return;
        this.paused = true;
        ctx.globalAlpha = 0.8;
        ctx.fillStyle = "#555555";
        ctx.fillRect(0, 0, this.real_xsize, this.ysize);
        ctx.globalAlpha = 1;
        ctx.font = "37pt Calibri";
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillStyle = "#efefef";
        ctx.fillText("[no focus]", this.real_xsize/2, this.ysize/2);
    }

    void resume()  {
        if (!this.paused)
            return;
        this.paused = false;
        ctx.fillStyle = "white";
        ctx.fillRect(0, 0, this.real_xsize, this.ysize);
        drawGrid();
        for (var x=0; x<this.grid.x; x++)
            for (var y=0; y<this.grid.y; y++)
                    drawGridSquare(new GridPoint(x,y));
        status.updateStatus(ctx, null);
    }
}

class DungeonState {
    DrawnGrid dg;
    List<Monster> monsters;
    Hero hero;
    int turn;
    bool hero_turn;
    bool game_over;

    DungeonState(this.dg)
    : monsters = [], turn=0, hero_turn=true {
        dg.drawGrid();
        dg.status.updateStatus(dg.ctx, "tiny dungeon started");
    }

    void spawn(Occupant o, GridPoint p) {
        dg.placeOnSquare(p, o);
    }

    void spawnHero(GridPoint p) {
        assert(hero == null);
        hero = new Hero(this);
        spawn(hero, p);
        dg.status.updateStatus(dg.ctx, "Move character (@) with arrows");
    }

    void spawnMonster(GridPoint p, Monster m) {
        monsters.add(m);
        spawn(m, p);
    }

    void keyDown(KeyboardEvent e) {
        //window.console.debug("Got keyboard event:" + e.toString() + " " + e.keyCode.toString());
        var input = null;
        switch(e.keyCode) {
            case 39: // arrow right
            case 76: // 'l'
            case 68: // 'd'
            input = Input.Right;
            break;

            case 37: // arrow left
            case 72: //'h'
            case 65: //'a'
            input = Input.Left;
            break;

            case 38: // arrow up
            case 75: //'k'
            case 87: //'w'
            input = Input.Up;
            break;

            case 40: // arrow down
            case 74: //'j'
            case 83: //'s'
            input = Input.Down;
            break;
        }

        if (input != null) {
            heroInput(input);
        }
    }

    void heroInput(Input input) {
        // NB: This should not happen, since you are handling the monster moves
        // synchronously in this handler
        if (!hero_turn) {
            dg.status.updateStatus(dg.ctx, "Not your turn yet!");
        }

        if (game_over)
            return;

        //  input to a direction
        var dir;
        switch (input) {
            case Input.Up:
                dir = Grid.up;
                break;
            case Input.Down:
                dir = Grid.down;
                break;
            case Input.Left:
                dir = Grid.left;
                break;
            case Input.Right:
                dir = Grid.right;
                break;
        }

        // find the direction point
        var oldPoint = hero.location;
        var dirPoint = new GridPoint.fromDirection(oldPoint, dir);
        if (!dg.grid.validPoint(dirPoint)) {
            dg.status.updateStatus(dg.ctx, "Impossible move. Retry.");
            return;
        }

        Action ha; // hero acction
        var dirSquare = dg.grid.getSquare(dirPoint);
        if (dirSquare.isOccupied()) {
            ha = Action.newAttackAction(dirPoint);
        } else {
           ha = Action.newMoveAction(dirPoint);
        }
        resolveAction(hero, ha);
        heroActed();
    }

    void resolveAction(Occupant o, Action a) {
        switch (a.type) {
            case Action_.Move:
            GridPoint dest = a.asMove().dest;
            window.console.debug(o.toString() + " moves to " + dest.toString());
            var succ = dg.moveOccupant(o, dest);
            assert(succ);
            break;

            case Action_.Attack:
            GridPoint tp = a.asAttack().target;
            Occupant to = dg.grid.getSquare(tp).occupant;
            window.console.debug(o.toString() + " Attacks " + to.toString() + "!");
            dg.hitOccupant(to);
            // one hit, one kill
            dg.removeOccupant(to);
            if (to == hero) {
                this.game_over = true;
            } else {
                monsters.remove(to);
            }
            break;

            case Action_.Wait:
            window.console.debug(o.toString() + " cannot move this turn");
            break;

            case Action_.Invalid:
            assert(false);
            break;
        }
    }

    void heroActed() {
        // hero moved
        hero_turn = false;
        for (var m in monsters) {
            Action a = m.takeTurn();
            resolveAction(m, a);
            dg.drawGridSquare(m.location);
        }

        if (game_over) {
            dg.status.updateStatus(dg.ctx, "Game over :(");
        } else {
            turn++;
            dg.status.updateStatus(dg.ctx, "Turn: " + turn.toString());
            hero_turn = true;
        }
    }
}

void startDungeon()
{
    CanvasElement canvas = document.querySelector('#canvas');
    CanvasRenderingContext2D ctx = canvas.getContext('2d');

    DrawnGrid dg = new DrawnGrid(new Grid(3,3), canvas.width, canvas.height, ctx);
    canvas.focus();
    dg.paused = false;
    dg.drawGrid();
    DungeonState dungeon = new DungeonState(dg);
    dungeon.spawnHero(new GridPoint(0,0));
    dungeon.spawnMonster(new GridPoint(1,2), new Zombie(dungeon, false));

    canvas.onKeyDown.listen( (e) {
        dungeon.keyDown(e);
    });

    canvas.onBlur.listen( (e) {
        //dg.pause();
    });

    canvas.onFocus.listen( (e) {
        dg.resume();
    });
}

// TODO:
// - show attack
// x skeleton moves every other turn
// x turn progression
// x skeleton
// x restart button
// x keyboard input
// x status text

void main() {
    startDungeon();
    ButtonElement button = querySelector('#reset');
    button.onClick.listen( (e) {
        startDungeon();
    });
}
