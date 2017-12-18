zTimeOn <- 0;
gTimeOn <- 0;
cycles <- 0;
zSurfaceHigh <- 0;
zSurfaceLow <- 100;
zGapHigh <- 0;
zGapLow <- 100;
gSurfaceHigh <- 0;
gSurfaceLow <- 100;
gGapHigh <- 0;
gGapLow <- 100;
impTempHigh <- 0;
impTempLow <- 100;

device.on("sendValues", function(currentValues) {
    cycles++;
    if (currentValues.zSurface > zSurfaceHigh) {
      zSurfaceHigh = currentValues.zSurface;
    }
    if (currentValues.zSurface < zSurfaceLow) {
      zSurfaceLow = currentValues.zSurface;
    }

    if (currentValues.zGap > zGapHigh) {
      zGapHigh = currentValues.zGap;
    }
    if (currentValues.zGap < zGapLow) {
      zGapLow = currentValues.zGap;
    }

    if (currentValues.gSurface > gSurfaceHigh) {
      gSurfaceHigh = currentValues.gSurface;
    }
    if (currentValues.gSurface < gSurfaceLow) {
      gSurfaceLow = currentValues.gSurface;
    }

    if (currentValues.gGap > gGapHigh) {
      gGapHigh = currentValues.gGap;
    }
    if (currentValues.gGap < gGapLow) {
      gGapLow = currentValues.gGap;
    }

    if (currentValues.impTemp > impTempHigh) {
      impTempHigh = currentValues.impTemp;
    }
    if (currentValues.impTemp < impTempLow) {
      impTempLow = currentValues.impTemp;
    }

    if (currentValues.zLight == 1) {
      zTimeOn++;
    }
    if (currentValues.gLight == 1) {
      gTimeOn++;
    }
    server.log("gLight:" + currentValues.zLight);
    server.log("gTimeOn:" + zTimeOn);
    server.log("gAmbient:" + currentValues.zAmbient);
    server.log("gSurface:" + currentValues.zSurface + " low:" + zSurfaceLow + " high:" + zSurfaceHigh);
    server.log("gGap:" + currentValues.zGap + " low:" + zGapLow + " high:" + zGapHigh);
    server.log("--------------------------------------");
    server.log("zLight:" + currentValues.gLight);
    server.log("zTimeOn:" + gTimeOn);
    server.log("zAmbient:" + currentValues.gAmbient);
    server.log("zSurface:" + currentValues.gSurface + " low:" + gSurfaceLow + " high:" + gSurfaceHigh);
    server.log("zGap:" + currentValues.gGap + " low:" + gGapLow + " high:" + gGapHigh);
    server.log("--------------------------------------");
    server.log("impTemp:" + currentValues.impTemp + " low:" + impTempLow + " high:" + impTempHigh);
    server.log("cycles:" + cycles);
    server.log("======================================");
});
