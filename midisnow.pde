import themidibus.*;

/***
 * Processing Snowfall Simulation
 * But also now it's an organic sequencer
 *
 * @author Avery Brooks
 * @copyright 2017/2018
 */

long[] noteTimers = new long[24]; // the length of this array controls our note count globally so make it work
long   noteLength = 250; // all notes urn off automatically after a quarter of a second i guess

MidiBus myBus;
Grid grid;

int particleCount = 200;
particle[] snowflakes = new particle[particleCount];

// how many levels of wind can we have? (same as levels of snow field distances)
int maxZ = 5;
// this is used to generate wind interference to accelerate the particles as they move relative to the x,y noisemap
noisemap[] wind = new noisemap[ maxZ + 1 ];

boolean windVisible     = false;
boolean debugVisible    = true;
boolean arrowsVisible   = false;
boolean lineSeqVisible  = true;
boolean framerateVisible = false;

boolean debugOneLayer   = false;
int debugOneLayerTarget = 1;

boolean gravityEnabled  = true;

boolean calculateAccel  = true;
int accelFrameCounter   = 0;

boolean windFades       = true;
float windEffect        = 0.25f;
long lastChangeMS       = 0;
long lastUpdateMS       = 0;
int windChangeRateMS    = 1500; // how often do new wind effects come in?
int windUpdateRateMS    = 200; // how often do we apply shifts like fading / motion
int visibleMap          = 1;
long lastMapMS          = 0;
long mapChangeRateMS    = windChangeRateMS;

// wind which sticks around and is applied to every particle in the system relative {x,y,z}
float[] ambientWind     = {0, 0, 0};

PImage snowflake;
PGraphics snowflakeSource;

int bgFillCount         = 1;
filler[] bgFill         = new filler[ bgFillCount ];
int selectedBgFill      = 0;

// this is used to determine the relative population of the fields
int[] fakeWeightedDistances = {
  // 5,5,5,5,5,5,5,5,5,
  4, 4, 4, 4, 4, 4,
  3, 3, 3, 3,
  2, 2,
  1
};

int fakeRandom() {
  return fakeWeightedDistances[(int) random(0, fakeWeightedDistances.length)];
}

float randomFloat() {
  return random(1, maxZ);
}

void setup() {

  fullScreen(P3D);
  // size(640, 480, P3D);
  frameRate(60);

  // fullScreen(P3D);

  noCursor();

  //snowflake = loadImage("snowflake1.png");
  //snowflake = loadImage("snowflake2.png");
  snowflake = loadImage("snowflake3.png");

  for (int z = 1; z <= maxZ; z++) {
    wind[z] = new noisemap(width, height, 32);
  }

  for (int i = 0; i < particleCount; i++) {
    snowflakes[i] = spawn(false);
    snowflakes[i].id = i;
  }

  lastChangeMS = millis();
  lastUpdateMS = millis();

  long startDrawMS = millis();
  long prevDrawMS = startDrawMS;

  for (int f = 0; f < bgFillCount; f++) {
    prevDrawMS = millis();
    bgFill[f] = new filler(width, height);
    bgFill[f].updateBackgroundFill(100, 127, 255, 255);
    // bgFill[f].randomize();
    // bgFill[f].drawBackgroundFill();
    println((millis() - startDrawMS) + " ms elapsed");
    println((millis() - prevDrawMS) + " ms for this round");
  }

  println((millis() - startDrawMS) + " ms elapsed");





  MidiBus.list();

  // arturia, 'To Logic' bridge -- check these at run time
  myBus = new MidiBus(this, 2, 1); // Create a new MidiBus using the device index.

  grid = new Grid(
    this.getGraphics(), // PGraphics
    width, // Grid Width int
    100, // Grid height
    0, // int x
    height - 200, // int y
    noteTimers.length, // int rows
    1, // int cols
    0, // start note
    100 // , // default velocity
  );






  background(0);
}

void draw() {

  long now = millis();
  
  // auto noteOff everyone
  for(int i = 0; i < noteTimers.length; i++) {
    if (noteTimers[i] > 0 && now - noteTimers[i] > noteLength) {
      grid.noteAt(i % grid.getCols(), 0).off();
      noteTimers[i] = -1;
    }
  }

  //turn on and off accel calc
  //accelFrameCounter++;
  //if (accelFrameCounter % 30 == 0) {
  //  accelFrameCounter = 0;
  //  calculateAccel = !calculateAccel;
  //}

  noCursor();

  // clear the last frame
  background(0,10,100);
  // or use bg canvas buffer
  // fill(0);
  // rect(0, 0, width, height);

  //imageMode(CORNER);
  // tint(255);
  // image(bgFill[selectedBgFill].getFill(), 0, 0);

  // tint(255);
  // draw the noisemap for now
  if (windVisible) {

    imageMode(CORNER);

    for (int z = 1; z < maxZ; z++) {

      if (debugOneLayer && z != debugOneLayerTarget)
        continue;

      image(wind[z].mappy, 0, (z - 1) * wind[z].mappy.height);
    }

    if (millis() - lastMapMS > mapChangeRateMS) {
      visibleMap = visibleMap + 1 <= maxZ ? visibleMap + 1 : 1;
      lastMapMS = millis();
    }
  }

  //  draw the background gradient

  // handle all physics and draw the snowflakes
  // for(particle snowflake : snowflakes) {
  for (int i = 0; i < particleCount; i++) {

    if (debugOneLayer && snowflakes[i].zIndex != debugOneLayerTarget)
      continue;

    if (calculateAccel) {

      float[] accel = wind[snowflakes[i].zIndex].getXY((int) snowflakes[i].x, (int) snowflakes[i].y);
      // particle.changeAccel( wind.getXY((int) snowflakes[i].x, (int) snowflakes[i].y );

      float xF = (accel[0] + ambientWind[0]) * windEffect;
      float yF = (accel[1] + ambientWind[1]) * windEffect;
      float zF = (accel[2] + ambientWind[2]) * windEffect;

      snowflakes[i].changeAcceleration( xF, yF, zF );

    }

    snowflakes[i].update();

    snowflakes[i].draw();
    
    if (!snowflakes[i].hitSomebody() && snowflakes[i].x > 0 && snowflakes[i].y > grid.y && snowflakes[i].y < height && snowflakes[i].x < width) {
      
      int noteConcern = (int) ( snowflakes[i].x / grid.getCols() ) % grid.getCols() ;

      if (noteConcern >= 0 && noteConcern < grid.getCols()) {
        
        if (snowflakes[i].x > grid.noteAt(noteConcern, 0).y + grid.noteAt(noteConcern, 0).h) {
          snowflakes[i].iHitSomebody();
          println("NOTE ON FUCKER!");
          grid.noteAt(noteConcern, 0).on();
        } else {
          snowflakes[i].iAmFree();
          // grid.noteAt(noteConcern, 0).off();
        }
    
      }

    }

    if (lineSeqVisible && i > 0 && i < particleCount - 1) {
      stroke(255, 0, 0);
      line(snowflakes[i - 1].x, snowflakes[i - 1].y, snowflakes[i].x, snowflakes[i].y);
    }

    if (!snowflakes[i].inBoundsX(width)) {
      snowflakes[i].loopX(width); // pacman style
    }

    if (snowflakes[i].inBoundsY(height)) {
      snowflakes[i].backToTheTop(width, height);
      // snowflakes[i].die();
      // snowflakes[i] = spawn(true);
    }
  }

  if (millis() - lastUpdateMS > windUpdateRateMS) {
    for (int z = 1; z < maxZ; z++) {

      if (debugOneLayer && z != debugOneLayerTarget)
        continue;

      if (windFades)
        wind[z].fade();
    }
    lastUpdateMS = millis();
  }

  if (millis() - lastChangeMS > windChangeRateMS) {
    for (int z = 1; z < maxZ; z++) {

      if (debugOneLayer && z != debugOneLayerTarget)
        continue;

      if (random(0, 1) > .4) {
        wind[z].addWindArea();
      }

      if (random(0, 1) > .9) {
        wind[z].mappy.filter(INVERT);
      }
    }
    lastChangeMS = millis();
  }

  if (framerateVisible) {
    fill(255);
    String fr = String.valueOf(frameRate);
    rect(0, 0, textWidth(fr), 200);
    // textAlign(CORNER);
    fill(0);
    text(fr, 10, 10);

    fill(calculateAccel ? 255 : 0);
    rect(0,190,20,20);
  }

  

  grid.draw();
}


// with the received values.
void controllerChange(int channel, int number, int value) {

  println( channel, number, value );
  
  
}



// use noteTimers[] to determine when things die automatically

// with the received values.
void noteOn(int channel, int number, int value) {
  println("noteOn", channel, number, value );
  grid.noteAt(number % grid.getCols(),0).select();
  // grid.noteAt(number % grid.getCols(),0).toggle();
  noteTimers[number % grid.getCols()] = millis(); // grid.noteAt(i % grid.getCols(), 0).off();
}

void noteOff(int channel, int number, int value) {
  println("noteOff", channel, number, value );
  grid.noteAt(number % grid.getCols(),0).deselect();  
}



/**
 * handle routing keys to the API
 */
void keyPressed() {
  routeAPI(keyCode);
}

void routeAPI(int keyCode) {

  println(keyCode);

  switch (keyCode) {

  case 16: // shift
    break;

  case 70: // f
    framerateVisible = !framerateVisible;
    break;

  case 71: // g
    gravityEnabled = !gravityEnabled;
    break;

  case 38: // up
    ambientWind[1]--;
    break;

  case 40: // down
    ambientWind[1]++;
    break;

  case 37: // left
    ambientWind[0]--;
    break;

  case 39: // right
    ambientWind[0]++;
    break;

  case 27: // esc ?
    break;

  case 81: // Q
    selectedBgFill = selectedBgFill - 1 >= 0 ? selectedBgFill - 1 : 0;
    break;

  case 87: // W
    selectedBgFill = selectedBgFill + 1 < bgFill.length ? selectedBgFill + 1 : bgFill.length - 1;
    break;

  case 69: // E
    lineSeqVisible = !lineSeqVisible;
    break;

  case 82: // R
    debugVisible = !debugVisible;
    break;

  case 84: // T
    windVisible = !windVisible;
    break;

  case 89: // Y
    arrowsVisible = !arrowsVisible;
    break;
  
  case 85: // U
    break;

  case 73: // I
    break;

  case 79: // O
    break;

  case 80: // P
    break;

  }

}



/**
 * Factory method to get a new particle within normal parameters
 * @return particle
 */
particle spawn(boolean offscreen) {
  float x = random(0, width);
  float y = offscreen ? - snowflake.height : random(0, height);
  float z = fakeRandom(); // (0, maxZ);

  float d = random(20, 40); // (float) fakeRandom();
  return new particle(x, y, z, d);
}

class noisemap {

  PGraphics mappy;
  PImage fader;

  int scale = 1;

  noisemap(int mapWidth, int mapHeight, int scale) {

    this.scale = scale;

    // integer division - get xpos/ypos in our scale, eg: 1->8 1->16, whatev
    // mappy = createImage(mapWidth / scale, mapHeight / scale, RGB);
    mappy = createGraphics(mapWidth / scale, mapHeight / scale);
    fader = createImage(mapWidth / scale, mapHeight / scale, ARGB);

    fillFader();
    fillMap();
  }

  void fillFader() {

    for (int x = 0; x < fader.width; x++) {
      for (int y = 0; y < fader.height; y++) {
        fader.set(x, y, color(128, 128, 128, 13)); // roughly 5% opacity
      }
    }
  }

  void fillMap() {

    mappy.beginDraw();

    for (int x = 0; x < mappy.width; x++) {
      for (int y = 0; y < mappy.height; y++) {
        mappy.set(x, y, color(128, 128, 128)); // ,0));
      }
    }

    mappy.endDraw();

    // add some wind!
    for (int i = 0; i < 10; i++) {
      addWindArea();
    }
  }

  void fade() {
    mappy.blend(fader, 0, 0, fader.width, fader.height, 0, 0, mappy.width, mappy.height, BLEND);
  }

  void addWindArea() {

    int startX = (int) random(0, mappy.width);
    int startY = (int) random(0, mappy.height);
    int endX = (int) random(startX, mappy.width);
    int endY = (int) random(startY, mappy.height);

    int colorR = color(random(0, 255), random(0, 255), 128);

    mappy.beginDraw();
    mappy.fill(colorR);
    mappy.ellipseMode(CORNER);
    mappy.ellipse(startX, startY, endX, endY);
    mappy.endDraw();

    //for(int x = startX; x < endX; x++) {
    //  for(int y = startY; y < endY; y++) {
    //    mappy.set(x, y, colorR);
    //  }
    //}
  }

  float[] getXY(int x, int y) {

    float[] colorAtXY = {
      0, 0, 0
    };

    x = x / scale;
    y = y / scale;

    if (x < 0 || x >= mappy.width || y < 0 || y > mappy.height) {
      return colorAtXY;
    }

    color c = mappy.get(x, y);

    int r = (c >> 16) & 0xFF;
    int g = (c >> 8 ) & 0xFF;
    int b =  c        & 0xFF;

    colorAtXY[0] = ((float) r - 128.0f) / 128.0f;
    colorAtXY[1] = ((float) g - 128.0f) / 128.0f;
    colorAtXY[2] = ((float) b - 128.0f) / 128.0f;

    return colorAtXY;
  }
}

class particle {

  int id = 0;

  int zIndex = 1;

  float x = 0;
  float y = 0;
  float z = 0;
  float d = 2;

  float gravity = 0.5;

  float accelX = 0;
  float accelY = 0;
  float accelZ = 0;

  float velX = 0;
  float velY = 0;
  float velZ = 0;

  float friction = 0.85;

  // consider "density" for like, ice vs snow to affect terminal velocity
  float terminalXYZ = 20;

  boolean moves = true;

  boolean hit   = false;

  particle(float x, float y, float z, float d ) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.d = d;

    this.zIndex = (int) z; // relative to windMap needs int, fuck it (OR getZ() which handles range and then we can deal with out of bounds and whatever ->
  }

  void backToTheTop(int w, int h) {
    this.x = random(0 - 20, w + 20);
    this.y = random(0 - h, 0);
  }

  void loopX(int w) {
    if (this.x <= 0)
      this.x = w + this.d;
    else
      this.x = -this.d;
  }

  void die() {
    this.moves = false;
  }

  boolean hitSomebody() {
    return hit;
  }
  
  void iHitSomebody() {
    hit = true;
  }
  
  void iAmFree() {
    hit = false;
  }

  boolean inBounds(int w, int h) {
    return this.y < h + d && this.x < w + d && this.x + d > 0;
  }

  boolean inBoundsX(int w) {
    return this.x < w + d && this.x + d > 0;
  }

  boolean inBoundsY(int h) {
    return this.y > h + d;
  }

  float terminalVelocity(float terminal, float current) {

    if (current == 0)
      return 0;

    if (current < 0 && current < -terminal)
      return -terminal;

    if (current > terminal)
      return terminal;

    return current;
  }

  void changeAcceleration(float x, float y, float z) {

    this.accelX += x;
    this.accelY += y;
    // this.accelZ += z;
  }

  void update() {

    if (this.moves) {
    
      // positive Y accel affected by gravity
      if (gravityEnabled)
        this.accelY += this.gravity;
  
      // velocity affected by acceleration
      this.velX += this.accelX;
      this.velY += this.accelY;
      // this.velZ += this.accelZ;
  
      // terminal velocity
      // not sure if this really helps actually - sort of sucks!
      // this.velX = terminalVelocity(this.terminalXYZ, this.velX);
      // this.velY = terminalVelocity(this.terminalXYZ, this.velY);
      // this.velZ = terminalVelocity(this.terminalXYZ, this.velZ);
  
      // velocity affected by friction
      this.velX *= this.friction;
      this.velY *= this.friction;
      // this.velZ *= this.friction;
  
      this.accelX *= this.friction;
      this.accelY *= this.friction;
      // this.accelZ *= this.friction;
  
      float distanceMult = (maxZ - this.z) / maxZ;
  
      // move!
      this.x += this.velX * distanceMult;
      this.y += this.velY * distanceMult;
      // this.z += this.velZ;
    }

  }

  void draw() {


    ellipseMode(RADIUS);

    float distanceMult = (maxZ - this.z) / maxZ;
    float d2 = distanceMult * d;

    //noStroke();
    //fill(255);
    //ellipse(x, y, d2, d2);

    imageMode(CENTER);
    image(snowflake, x, y, d2, d2);

    if (debugVisible) {

      // x/y vector type thing:
      fill(0);
      stroke(255);
      line(x, y, x+ this.velX * 2, y + this.velY * 2);
    }

    if (arrowsVisible) {

      // draw a big red arrow pointing to the XY pos

      fill(0);
      stroke(255, 0, 0);
      line(x, y + 100, x, y);
      line(x + 30, y + 30, x, y);
      line(x - 30, y + 30, x, y);

      text(this.id, this.x, this.y);
    }
  }
}

class filler {

  PGraphics backgroundFill;
  boolean shouldUpdateBackground = false;
  int[] lastColor = {128, 50, 255, 250};

  filler(int w, int h) {
    backgroundFill = createGraphics(w, h);
  }

  PGraphics getFill() {
    return backgroundFill;
  }

  void randomize() {
    updateBackgroundFill(
      (int) random(0, 255),
      (int) random(0, 255),
      (int) random(0, 255),
      (int) random(0, 255)
      );
  }

  void updateBackgroundFill(int r, int g, int b, int alpha) {

    if (lastColor[0] == r &&  lastColor[1] == g && lastColor[2] == b && lastColor[3] == alpha) {
      // don't do free work
      return;
    }

    lastColor[0] = r;
    lastColor[1] = g;
    lastColor[2] = b;
    lastColor[3] = alpha;

    drawBackgroundFill();
  }

  void drawBackgroundFill() {

    // void setGradient(int x, int y, float w, float h, color c1, color c2, int axis ) {

    noFill();

    int x = 0;
    int y = 0;
    int w = backgroundFill.width;
    int h = backgroundFill.height;

    color c1 = color(0, 0, 0, 255);
    color c2 = color(lastColor[0], lastColor[1], lastColor[2], lastColor[3]);

    for (int i = y; i <= y+h; i++) {
      float inter = map(i, y, y+h, 0, 1);
      color c = lerpColor(c1, c2, inter);
      backgroundFill.beginDraw();
      backgroundFill.stroke(c);
      backgroundFill.line(x, i, x+w, i);
      backgroundFill.endDraw();
    }
  }

}













class Grid extends Drawyguy {

  NoteBox[] notes = new NoteBox[128];

  int r;
  int c;

  Grid(PGraphics parent, int w, int h, int x, int y, int cols, int rows, int startNote, int defaultVelocity) { // , boolean toggleMode) {

    notes = new NoteBox[rows * cols];

    this.setParent(parent);
    this.setPosition(x, y);
    this.setSize(w, h);

    int currentNote = startNote;

    r = rows;
    c = cols;

    // note height / width
    int cW = w / cols;
    int rH = h / rows;
    
    println( cW, rH, w, h, cols, rows);

    currentNote = 40;

    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        int ind = grindex(c, r);
        notes[ind] = new NoteBox( parent, cW, rH, x + cW * c, y + rH * r, currentNote, defaultVelocity, ""+currentNote);
        currentNote += 3;
      }
    }
  }

  void draw() {

    // draw background ?
    //parent.rect(x, y, w, h);
    //parent.fill(100);
    //parent.stroke(0);

    // tell notes to draw
    // @todo only draw changed
    for (int i = 0; i < notes.length; i++) {
      notes[i].draw();
    }
  }

  // by pixel x/y
  NoteBox noteAtXY(int pX, int pY) {
    int rH = h / r;
    int cW = w / c;

    println( pX, pY );
    println( h, r, w, c);
    println(  pX / cW, pY / rH );

    return noteAt( pX / cW, pY / rH);
  }

  // by column/row
  NoteBox noteAt(int gX, int gY) {
    return notes[grindex(gX, gY)];
  }

  int grindex(int gX, int gY) {
    int ind = gY * c + gX;
    return ind;
  }

  int getRows() {
    return r;
  }

  int getCols() {
    return c;
  }
}

class NoteBox extends Drawyguy {

  String label     = "";
  int cornerRadius = 0;
  boolean active   = false;
  boolean selected = false;
  color onC        = color(160, 0, 0, 60);
  color onS        = color(140, 0, 0, 60);
  color offC       = color(100, 0, 0, 60);
  color offS       = color(60,  0, 0, 60);
  color selectedOC = color(255, 100, 0);
  color selectedC  = color(200, 0, 0);
  color selectedS  = color(170, 0, 0);
  color textC      = color(255, 0, 0);

  int note = 0;
  int velocity = 0;
  // int duration = 0; // or does the host deal with this ? maybe box just 
  // long lastOn = 0;

  NoteBox(PGraphics parent, int w, int h, int x, int y, int noteValue, int defaultVelocity, String noteLabel) {
    this.setParent(parent);
    this.setSize(w, h);
    this.setPosition(x, y);
    note = noteValue % 128;
    velocity = defaultVelocity;
    label = noteLabel;
  }

  void draw() {

    // text of note/vel/status ?

    parent.fill(
      active && selected ? selectedOC :
      active ? onC :
      selected ? selectedC : offC);

    parent.stroke(
      active && selected ? selectedOC :
      active ? onS :
      selected ? selectedS : offS);

    parent.rect( x, y, w, h, cornerRadius);

    // println( x, y, w, h );

    parent.fill(textC);
    parent.textAlign(CENTER, CENTER);
    parent.text(label, x + w/2, y + h/2);
  }

  void on() {
    on(-1, -1);
  }

  void on(int ln, int lv) {
    active = true;
    if (selected) {
      println("send note", note, velocity);
      myBus.sendNoteOn(
        1, //channel
        ln > 0 ? ln : note, 
        lv > 0 ? lv : velocity
      );
    }
  }

  void off() {
    off(-1, -1);
  }

  void off(int ln, int lv) {
    active = false;
    if (selected) {
      myBus.sendNoteOff(
        1, //channel
        ln > 0 ? ln : note, 
        lv > 0 ? lv : velocity
      );
    }
  }

  void toggle() {
    selected = !selected;
  }

  void select() {
    selected = true;
  }

  void deselect() {
    selected = false;
  }

  boolean isSelected() {
    return selected;
  }
}

class Drawyguy {

  PGraphics parent;

  int x;
  int y;
  int w;
  int h;

  Drawyguy() {
  }

  void draw() {
    // override this
  }

  void setSize(int _w, int _h) {
    w = _w;
    h = _h;
  }

  void setPosition(int _x, int _y) {
    x = _x;
    y = _y;
  }

  void setParent(PGraphics p) {
    parent = p;
  }
}