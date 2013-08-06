/*
 Pointl  
 by Chris Novello
 chrisnovello.com
 
 Pointl is a super simple template sketch for rendering images as fluttering 
 typographic pointillism.  
 
 In this incarnation...
-a random sample of pixels in the image are rendered as letters. 

-the draw area moves across the canvas, 
 effectively using one image to paint another. 

-you can have a slideshow of these images, 
 which you can also step through via OSC. 

-you load images by placing jpgs in the data folder 
 and labeling them numerically. 
 So for example place "0.jpg" and "1.jpg" in the data folder 
 and the sketch will have two slides.
 
 You might consider alternative loading schemes rather than renaming your jpgs. This sketch is just a quick and easy way to experiment with the base idea of the program
 
 You'll need the oscP5 library: (http://www.sojamo.de/libraries/oscP5/).

 My favorite font to use with this sketch is M01_CPS: (http://mfs.sub.jp/font/m01.zip).

*/

import processing.opengl.*;
import oscP5.*;
import netP5.*;

//Open Sound Control library objects and constants
OscP5 oscP5;
NetAddress myRemoteLocation;

final int PORT_FOR_INCOMING_OSC_MESSAGES = 8796;
final int PORT_FOR_OUTGOING_OSC_MESSAGES = 8797;

//Images:
ArrayList<PImage> images; //load all images from the data folder into this
PImage activeImage; // the image actively displayed from the bank of images
int imageIndex = 0; //index that determines which image is active

int framesSinceLastChange = 0; //frame counter used to determine speed of letter travel
PVector imageOrigin; //allows the image to be drawn from different origins than 0,0 - adds to the fluttery pointillist motion effect

//a time-based throttle on OSC messages to prevent frequent slide turnover
int timeSinceLastChange = 0;
int numberOfMSToDelay = 1;

//The phrase (text characters) to use as "pixels":
String letters[] = "perfectfuture".split("");
PFont font;

String name = "Pointl";


void setup() {

  //initialize font
  font = createFont("M01_CPS", width/24); 

  background(0);
  frameRate(30);
  size(640, 480, OPENGL); //not as crisp but more CPU efficient.. anyone know how to turn off OPENGL smoothing for text without crazy screen flicker??
  noStroke();

  //initialize OSC objects
  oscP5 = new OscP5(this, PORT_FOR_INCOMING_OSC_MESSAGES);
  myRemoteLocation = new NetAddress("127.0.0.1", PORT_FOR_OUTGOING_OSC_MESSAGES);

  images = new ArrayList<PImage>();//initialize the imageBank array

  //go through the data folder and find sequentially numbered images named with a number followed by ".jpg"
  boolean loadedAllImages = false;

  //load the images, resize them to match the sketch, and call loadpixels
  while (!loadedAllImages) {

    try { 
      // a more elegant way to do this would involve Java IO that checks for files before calling loadImage.. 
      //but this works okay too!
      PImage someImage = loadImage(imageIndex+".jpg");
      someImage.resize(width, height);
      someImage.loadPixels();
      images.add(someImage);
      println("Loaded image: "+imageIndex+".jpg");
      imageIndex++;
    } 
    catch (NullPointerException e) {
      if (imageIndex == 0) {
        println("No images to load! Add images to your data folder to use this program");
      } 
      else {
        println();
        println("Don't worry about that error.. the program just counted all the images it could find in your data folder.");
        println("It loaded all the images up to (and including) "+imageIndex+".jpg");
        println();
      }
      loadedAllImages = true;
    }
  }

  imageIndex = 0;
  activeImage = images.get(imageIndex); //initialize activeImage to the first image in the bank

  textFont(font);

  imageOrigin =  new PVector(0, 0); //setup the vector that allows the origin to move
} 


void draw() {


  moveImageOrigin(); //helper function for moving the origin of the image and causing graphical flutter

  //only draw a small number of characters each pass of the loop.. makes for image flutter + saves CPU
  for (int i = 0; i < 200; i++) {

    //pick a coordinate where you want to sample color from the activeImage 
    int x = int(random(width));
    int y = int(random(height));

    //use that as fill color for the text you draw
    fill(activeImage.get(x, y));

    //select a random letter from bank of letters
    String useThisText = letters[int(random(0, letters.length))];
    text(useThisText, x+imageOrigin.x, y+imageOrigin.y);
  }
  // if (frameCount%10==0) saveFrame();
}

void moveImageOrigin() { //slightly randomizes image origin which causes more image flutter effect
    //how often to reset the image's position 
    if (imageOrigin.x > width || imageOrigin.y > height  ) {
    imageOrigin.x=-15;
    imageOrigin.y=0;

    nextImage();
  }

  //how often to move the image's origin you draw the picture at
  else if (frameCount % 10 == 0) {

    if (framesSinceLastChange < 15) {
      randomlyMoveImage(7, 7);
    } 
    else {
      randomlyMoveImage(25, 12);
    }
  }

  framesSinceLastChange++;
}

void nextImage() {
  imageIndex++;

  if (imageIndex >= images.size()) {
    imageIndex = 0;
  }
  activeImage = images.get(imageIndex);
}
//Really simple OSC interface for stepping through pictures.
//TODO: add remote color getters/setters..

void randomlyMoveImage(int addAmount, int subtractAmount) {
  //50% of the time, move one direction, 50% of the time, move another
  if (int(random(2)) == 1) {
    imageOrigin.x += random(addAmount);
    imageOrigin.y += random(addAmount);
  } 
  else if (int(random(10)) == 1) {
    imageOrigin.x -= random(subtractAmount);
    imageOrigin.y -= random(subtractAmount);
  }
}

//Handle OSC messages, like incrementing the slideshow, etc
void oscEvent(OscMessage oscMessage) {

  String[] msgSplit = oscMessage.addrPattern().split("/"); // splits OSC msg
  if (msgSplit[1].equals(name)) {
    if (msgSplit[2].equals("NextGraphic")) {
      float value = oscMessage.get(0).floatValue();
      if (millis() - timeSinceLastChange > numberOfMSToDelay) { 
        timeSinceLastChange = millis();
        if (value == 1.0) {
          imageIndex++;
          if (imageIndex >= images.size()) {
            imageIndex = 0;
          }
          activeImage = images.get(imageIndex);
        }
      }
    }

    if (msgSplit[2].equals("FirstGraphic")) {

      float value = oscMessage.get(0).floatValue();

      imageIndex = 0;
      activeImage = images.get(0);
      activeImage.loadPixels();
    }

    //An experiment with new complex codebending type - a tuple carrying: x, y, and a color
    //allows sampling of color at a specific location via patching
    if (msgSplit[2].equals("GetColorAtCoordinate")) {

      float x = oscMessage.get(0).floatValue();
      float y = oscMessage.get(1).floatValue();

      int mappedX = int(map(x, 0., 1., 0, width));
      int mappedY = int(map(y, 0., 1., 0, height));

      OscMessage myMessage = new OscMessage("/"+name+"/CoordinatesWithColor");

      myMessage.add(x);
      myMessage.add(y);
      myMessage.add(activeImage.get(mappedX, mappedY));
      oscP5.send(myMessage, myRemoteLocation);
    }
  }
}


void keyPressed() {
  nextImage();
}

