/*  Azure Cognitive FaceAPI Demo. 
    Take a webcam picture with the spacebar and analyse it with the FaceAPI. 
    
    Uses the HTTPClient binaries (in the code folder):
    https://hc.apache.org/downloads.cgi
    
    More documentation:
    https://www.kasperkamperman.com/blog/using-azure-cognitive-services-with-processing
    
    Make sure you get the API subscription key and fill it in in the
    FaceAnalysis code (subscriptionKey). 
    
    kasperkamperman.com - 30-01-2018
*/

import processing.video.*;
import org.openkinect.freenect.*;
import org.openkinect.freenect2.*;
import org.openkinect.processing.*; //<>//

Kinect2 kinect2;

Capture cam;

PImage webcamFrame;
PImage webcamPicture;
PGraphics faceDataOverlay;

String onScreenText;
PFont SourceCodePro;

// camera in the setup in combination with other code, sometimes gives a
// Waited for 5000s error: "java.lang.RuntimeException: Waited 5000ms for: <"...
// so we will do init in the draw loop
boolean cameraInitDone = false;

// Face API – free: Up to 20 transactions per minute (so interval 3000ms)
// Face API - standard: Up to 10 transactions per second (so interval 100ms)
int minimalAzureRequestInterval = 3000; 

boolean isAzureRequestRunning = false;
int lastAzureRequestTime = 0; 

String azureFaceAPIData;

FaceAnalysis azureFaceAnalysis;

public void setup() {
  size(640,720,P3D);
  
  SourceCodePro = createFont("SourceCodePro-Regular.ttf",12);
  textFont(SourceCodePro);
  
  onScreenText = "Press space to take a picture and sent to Azure.";
  kinect2 = new Kinect2(this);
  kinect2.initVideo();
  kinect2.initDepth();
  //kinect2.initIR();
  //kinect2.initRegistered();
  // Start all data
  kinect2.initDevice();
  
   faceDataOverlay = createGraphics(kinect2.colorWidth,kinect2.colorHeight);
    faceDataOverlay.beginDraw();
    faceDataOverlay.clear();
    faceDataOverlay.endDraw();
}

void draw() {
  
  background(0);
 
  fill(255);
  webcamFrame= kinect2.getVideoImage();
  //doFaceAnalysis();  
    
  // keep the aspectratio correct based on the displayed width
  //float aspectRatio = cam.height/(float)cam.width;
  float aspectRatio = kinect2.colorHeight/(float)kinect2.colorWidth;
  int imageWidth = width;
    
  image(webcamFrame,0,0,imageWidth,aspectRatio*imageWidth);
  if(webcamPicture!=null) {
     image(webcamFrame,0,0,imageWidth,aspectRatio*imageWidth);
     image(faceDataOverlay,0,0,imageWidth,aspectRatio*imageWidth);
   }
   else
   {
   image(webcamFrame,0,0,imageWidth,aspectRatio*imageWidth);
   image(faceDataOverlay,0,0,imageWidth,aspectRatio*imageWidth);
   }
   
   onScreenText=str(kinect2.colorWidth);
  
  
  text(onScreenText,20,380,width-40,height-20);
  
  if(azureFaceAnalysis!=null) {
    if(azureFaceAnalysis.isDataAvailable()) {
      parseAzureFaceAPIResponse(azureFaceAnalysis.getDataString());
      onScreenText = azureFaceAnalysis.getDataString();
      isAzureRequestRunning = false;
    }
  }
 
}

void keyPressed() {
  // space-bar
  if(keyCode == 32) {
    startFaceAnalysis();  
  }
}

PVector depthToPointCloudPos(int x, int y, float depthValue) {
  PVector point = new PVector();
  point.z = (depthValue);// / (1.0f); // Convert from mm to meters
  point.x = (x - CameraParams.cx) * point.z / CameraParams.fx;
  point.y = (y - CameraParams.cy) * point.z / CameraParams.fy;
  return point;
}

void startFaceAnalysis() {
  
  if(isAzureRequestRunning == false) {
    if((millis() - minimalAzureRequestInterval) > lastAzureRequestTime) {
      webcamPicture = webcamFrame.get();
      onScreenText = "The request is sent to Azure.";
      isAzureRequestRunning = true;
      
      azureFaceAnalysis = new FaceAnalysis(webcamPicture);
    }
    else {
      onScreenText = "The request is sent to fast based on transactions per minute (free version every 3 seconds)";  
    }
  }
  else {
    onScreenText = "Previous data is still requested.";
  }
          
}

void parseAzureFaceAPIResponse(String azureFaceAPIData) {
  
    // we don't parse all the data
    // check the reference on other data that is available
    // https://westus.dev.cognitive.microsoft.com/docs/services/563879b61984550e40cbbe8d/operations/563879b61984550f30395236
    //print(azureFaceAPIData);
    JSONArray jsonArray = parseJSONArray(azureFaceAPIData);
    
    faceDataOverlay.beginDraw();
    faceDataOverlay.clear();
    
    for (int i=0; i < jsonArray.size(); i++) {
      JSONObject faceObject = jsonArray.getJSONObject(i);
      
      JSONObject faceRectangle  = faceObject.getJSONObject("faceRectangle");
      JSONObject faceLandmarks  = faceObject.getJSONObject("faceLandmarks");
      JSONObject faceAttributes = faceObject.getJSONObject("faceAttributes");
      
      int rectX = faceRectangle.getInt("left");   
      int rectY = faceRectangle.getInt("top");    
      int rectW = faceRectangle.getInt("width");  
      int rectH = faceRectangle.getInt("height"); 
      
      float puppilLeftX = faceLandmarks.getJSONObject("pupilLeft").getFloat("x");
      float puppilLeftY = faceLandmarks.getJSONObject("pupilLeft").getFloat("y");
      float puppilRightX = faceLandmarks.getJSONObject("pupilRight").getFloat("x");
      float puppilRightY = faceLandmarks.getJSONObject("pupilRight").getFloat("y");
      
      float noseTipX = faceLandmarks.getJSONObject("noseTip").getFloat("x");
      float noseTipY = faceLandmarks.getJSONObject("noseTip").getFloat("y");
      
      
      float age = faceAttributes.getFloat("age");
      String gender = faceAttributes.getString("gender");
      
      String faceInfo = "age: " + str(age) + "\n" + gender;
      JSONObject emotion = faceAttributes.getJSONObject("emotion");
      
      String [] emotions = { "anger", "contempt", "disgust", "happiness", "neutral", "sadness", "surprise" };
      
      float highestEmotionPercentage = 0.0;
      String highestEmotionString = "";
      
      for(int j = 0; j<emotions.length; j++) {
       float thisEmotionPercentage = emotion.getFloat(emotions[j]);
       
       if(thisEmotionPercentage > highestEmotionPercentage) {
        highestEmotionPercentage = thisEmotionPercentage; 
        highestEmotionString = emotions[j];
       }
      }
      
      String faceEmotion = "Facial Expression: " +highestEmotionString + "("+str(highestEmotionPercentage)+")";
      
      //Facial Hair
      JSONObject facialHair = faceAttributes.getJSONObject("facialHair");
      
      float beardPercentage = facialHair.getFloat("beard");
      float moustachePercentage = facialHair.getFloat("moustache");
      float sideburnsPercentage = facialHair.getFloat("sideburns");
     
      String facialHairString="Facial Hair:  No";
     
      if(sideburnsPercentage>0.5) facialHairString ="Facial Hair:  Sideburns";
      if(moustachePercentage>0.5) facialHairString ="Facial Hair:  Moustache";
      if(beardPercentage>0.5) facialHairString ="Facial Hair:  Beard";
      
      
      //Gaze
      
      JSONObject headPose = faceAttributes.getJSONObject("headPose");
      
       float roll = headPose.getFloat("roll");
      float yaw = headPose.getFloat("yaw");
      float pitch = headPose.getFloat("pitch");
      
      String lookingAt ="Gaze: Center";
      
      if(yaw>10) lookingAt = "Gaze: Left";
      if(yaw<-10) lookingAt = "Gaze: Right";
      
      //Glasses
      
      String glasses = faceAttributes.getString("glasses");
      String glassesText="Glasses: Yes";
      if(glasses.equals("NoGlasses")) glassesText="Glasses:  No";
      
      
      //Hair color
      JSONObject hair = faceAttributes.getJSONObject("hair");
      
      float bald = hair.getFloat("bald");
      JSONArray hairColor= hair.getJSONArray("hairColor");
      
      float highestColorPercentage = 0.0;
      String highestColorString = "";
      
      for (int j=0; j<hairColor.size(); j++) {
         JSONObject thisColor = hairColor.getJSONObject(j);
         String thisColorName= thisColor.getString("color");
         float thisColorPercentage = thisColor.getFloat("confidence");
         
         if(thisColorPercentage > highestColorPercentage) {
        highestColorPercentage = thisColorPercentage; 
        highestColorString = thisColorName;
         }
      }
            
      String faceHairColor = "Hair color: "+ highestColorString + "("+str(highestColorPercentage)+")";
      
      if(bald>0.7) faceHairColor = "Bald" + "("+str(bald)+")";
      
      faceDataOverlay.stroke(0,255,0);
      faceDataOverlay.strokeWeight(4);
      
      //faceDataOverlay.noFill();
      faceDataOverlay.fill(255,128);
      
      faceDataOverlay.rect(rectX,rectY,rectW,rectH);
      
      faceDataOverlay.fill(255,0,0);
      faceDataOverlay.noStroke();
      faceDataOverlay.ellipse(puppilLeftX,puppilLeftY,8,8);
      faceDataOverlay.ellipse(puppilRightX,puppilRightY,8,8);
      faceDataOverlay.ellipse(noseTipX,noseTipY,8,8);
      
      faceDataOverlay.fill(0,255,0);
      faceDataOverlay.stroke(0);
      faceDataOverlay.textSize(32);
      faceDataOverlay.textAlign(LEFT, BOTTOM);
      
      faceDataOverlay.text(faceInfo,rectX+5,rectY,rectW,rectH-5);
      //faceDataOverlay.text(faceInfo,rectX,rectY+rectH);
       
      if(rectY<((faceDataOverlay.height-rectH)/2)) { 
        // face on upperhalf of picture
        faceDataOverlay.textAlign(LEFT, TOP);
        faceDataOverlay.text(faceEmotion,rectX,rectY+rectH+10);
        faceDataOverlay.text(faceHairColor,rectX,rectY+rectH+50);
        faceDataOverlay.text(facialHairString,rectX,rectY+rectH+90);
        faceDataOverlay.text(glassesText,rectX,rectY+rectH+130);
        faceDataOverlay.text(lookingAt,rectX,rectY+rectH+170);
      } 
      else {
        faceDataOverlay.textAlign(LEFT, BOTTOM);
        faceDataOverlay.text(faceEmotion,rectX,rectY);
        faceDataOverlay.text(faceHairColor,rectX,rectY-40);
        faceDataOverlay.text(facialHairString,rectX,rectY-80);
        faceDataOverlay.text(glassesText,rectX,rectY-120);
        faceDataOverlay.text(lookingAt,rectX,rectY-160);
      }
      
    }
    
    faceDataOverlay.endDraw();
  
}

void initCamera() { 
  
  // make sure the draw runs one time to display the "waiting" text
  if(frameCount<2) return;
  
   String[] cameras = Capture.list();

   if (cameras.length == 0) {
    println("There are no cameras available for capture.");
    exit();
   } 
   else {
    println("Available cameras:");
    printArray(cameras);

    // The camera can be initialized directly using an element
    // from the array returned by list():
    cam = new Capture(this, cameras[0]);
    
    // Start capturing the images from the camera
    cam.start();
    
    while(cam.available() != true) {
      delay(1);//println("waiting for camera");
    }
    
    // read once to get correct width, height
    cam.read();
    
    // create the overlay PGraphics here
    // so it's exactly the   size of the camera
      
    
    cameraInitDone = true;
    
    onScreenText = "";
  }
   
}
