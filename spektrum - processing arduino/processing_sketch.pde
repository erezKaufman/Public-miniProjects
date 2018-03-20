import processing.serial.*;
import java.util.ArrayList;

// ---- import sound ------
import processing.sound.*;
SinOsc[] sineWaves; // Array of sines
float[] sineFreq; // Array of frequencies
int numSines = 5; // Number of oscillators to use
float time = 0;
float curyoff = random(0, 1);
float curxoff = random(-0.5, 0.5);
int time_limit = 1000;
float curYOff = 0;
// ---- end sound ------

// ----- sound SENSOR -----
int treshold = 200;
boolean isLoud = false;
float time_of_loud; // variable to hold the amount of time there is "noise"
int noiseLimit = 5000; // the limit that we decide the art will be in noise mode
int i;
float r_color;
float g_color;
float b_color;
float fill_time;
// ----- end of sound SENSOR -----


// ---- import sensors ------
Serial sonarPort;
Serial soundPort;
float sonarOutput;
float soundOutput;


void setup() {

  /* RELEASE THIS WHEN WE HAVE SENSORS! 
   
   ArrayList<String> pnames = findPort();
   // if there are less than two sensors - print there is an error and exit the program 
   if (pnames.size() < 2){
   println("ERROR: Less than 2 or none sensors are connected. current amount of sensors connected: "+pnames.size());
   exit(); 
   }
   String sonarName = pnames.get(0);  // get first sensor name. supposed to be sonar
   String soundName = pnames.get(1);  // get second sensor name. supposed to be sound
   sonarPort = new Serial(this, sonarName,9600); // init sonar object
   soundPort = new Serial(this, soundName,9600); // init sound object 
   
   // don't generate a serialEvent() unless you get a newline character:
   sonarPort.bufferUntil ('\n'); 
   soundPort.bufferUntil ('\n'); 
   
   */

  // ------- init sound  --------------//
  sineWaves = new SinOsc[numSines]; // Initialize the oscillators
  sineFreq = new float[numSines]; // Initialize array for Frequencies

  for (int i = 0; i < numSines; i++) {
    // Calculate the amplitude for each oscillator
    float sineVolume = (1.0 / numSines) / (i + 1);
    // Create the oscillators
    sineWaves[i] = new SinOsc(this);
    // Start Oscillators
    sineWaves[i].play();
    // Set the amplitudes for all oscillators
    sineWaves[i].amp(sineVolume);
  }
  time = millis();
  fill_time = millis();
  i = 0;
  r_color = 0;
  g_color = 0;
  b_color = 0;
}


void draw() {
  //  I want to make (based on the sonar and sound output) is a sceen that makes shapes - that based on the output of the sonar will generate high/low pitch - and also
  //  change the shapes themself. 
  //  The sound output will detarmin color changing of the shapes in the window
    setYoffset();
    setTimeLimit();
    createSound();
    drawShape();
    if (isLoud){
        // TODO handle when loud
    }
    else{
      // TODO handle when not looud
    }
}

/**
 * the function will search for avilable ports and returns list of ports names
 */
static final ArrayList<String> findPort() {
  String[] ports = Serial.list();
  ArrayList<String> portsNames = new ArrayList<String>();
  for (String p : ports) {
    for (int i = 1; i <= 20; ++i) {
      if (p.equals("COM" + i)) {
        portsNames.add(p);
      }
    }
  }
  return portsNames;
}

/**
* function that creates the sound of the art
*/
void createSound() {
  if (millis()-time > time_limit) { // change the time_limit according to the output of the sonar 
    curxoff = random(-0.5, 0.5);
    time = millis();
  }
  float yoffset = curYOff; // change this according to the output of the sonar

  //Map yoffset logarithmically to 150 - 1150 to create a base frequency range
  float frequency = pow(1000, yoffset) + 150;
  //Use mouseX mapped from -0.5 to 0.5 as a detune argument
  float detune = curxoff;

  for (int i = 0; i < numSines; i++) { 
    sineFreq[i] = frequency * (i + 1 * detune);
    // Set the frequencies for all oscillators
    sineWaves[i].freq(sineFreq[i]);
  }
}


/**
 * the function will sets the frequency of the tone by the sonar output
 */
void setYoffset() {
  if (sonarOutput ==0) {
    // TODO handle this
  } else {
    curYOff = sonarOutput/500;
  }
}

/**
 * thefunction sets the time limitfor each tone by the sonar output
 */
void setTimeLimit() {
  time_limit = int(sonarOutput-100)/900;
}

/**
* the serial event reader for every port
*/
void serialEvent(Serial myPort) {
  String inString = myPort.readStringUntil('\n');
  // if the sonar port is working
  if (myPort == sonarPort) {
    sonarOutput = float(inString);
  }
  // if the sound port is working
  if (myPort == soundPort) {
    soundOutput = float(inString);
    // if the sound from the sensor is larger than the treshold, set the loud mode to true, and init the timestamp for the mode
    if (soundOutput > treshold){
        isLoud = true;
        time_of_loud = millis();
    }
    // if we are in loud mode, and the time limit for the mode had passed, go out from lud mode
    if (isLoud && (millis()-time_of_loud) > noiseLimit){
      isLoud = false;
    }
  }
}

/**
* the function will draw a shapes by the depending on the output of the sensors.
* if we are in loud mode (the sound sensor will work) - the colors will be warmer and the shape will be of lines.
* if we are not in loud mode, the shape will be of a circle and the colors will be cooler.
*/
void drawShape(){
    if (millis()-time > 1000){
        if (isLoud){
            r_color = random(0, 0);
            g_color = random(0, 255);
            b_color = random(0, 255);      
        }
        else{
            r_color = 0;
            g_color = random(0, 255);
            b_color = random(0, 255); 
        }
    time = millis();
    }
    fill (r_color,g_color,b_color);
    if (isLoud){
        stroke(sin(i*0.03)*127.5+127.5,cos(i*0.02)*127.5+127.5,60);
        rotate(15/100);
        line( //arguments can be written on separate lines - easier to read
          sin(i*0.029)*width*0.5+(width*0.5), //start x
          sin(i*0.04)*height*0.5+(height*0.5), //start y
          sin(i*0.03)*width*0.5+(width*0.5), //stop x
          sin(i*0.012+0.3)*height*0.5+(height*0.5) //stop y
        );
    }
    else{
        ellipse (    (sin(i*0.0029)*width*1.5+(width*1.05))%400, //start x
        (sin(i*0.004)*height*1.5+(height*1.05)%400), //start y
        (sin(i*0.004)*height*0.5+(height*1.05))%400, //stop x
        (sin(i*0.004)*height*0.5+(height*01.05))%400); //stop y);
    }
    i ++;
}