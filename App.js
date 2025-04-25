import React, { useRef, useEffect, useState } from 'react';
import { Animated, View, Text, StyleSheet, Button, Image, Dimensions, PanResponder } from 'react-native';
import { Picker } from '@react-native-picker/picker';
import { Audio } from 'expo-av';

const { height, width } = Dimensions.get('window');

export default function App() {
  const [focusDuration, setFocusDuration] = useState(25 * 60);
  const [breakDuration, setBreakDuration] = useState(25 * 60);
  const [showPickers, setShowPickers] = useState(false);
  const [logoVisible, setLogoVisible] = useState(true);
  const [timerRunning, setTimerRunning] = useState(false);
  const [isFocusTime, setIsFocusTime] = useState(true);
  const [elapsed, setElapsed] = useState(0);
  const [totalTime, setTotalTime] = useState(focusDuration);
  const [completedCycles, setCompletedCycles] = useState(0);
  const [showButton, setShowButton] = useState(true);

  const logoOpacity = useRef(new Animated.Value(1)).current;
  const pickerTranslateY = useRef(new Animated.Value(height)).current;
  const intervalRef = useRef(null);

  const [sound, setSound] = useState(null);

  useEffect(() => {
    const loadSound = async () => {
      const { sound } = await Audio.Sound.createAsync(require('./assets/notification.wav'));
      setSound(sound);
    };
    loadSound();
    return () => {
      if (sound) sound.unloadAsync();
    };
  }, []);

  useEffect(() => {
    setTimeout(() => {
      Animated.timing(logoOpacity, {
        toValue: 0,
        duration: 800,
        useNativeDriver: true,
      }).start(() => {
        setLogoVisible(false);
        setShowPickers(true);
        animatePickersIn();
      });
    }, 1500);
  }, []);

  const animatePickersIn = () => {
    Animated.timing(pickerTranslateY, {
      toValue: 0,
      duration: 600,
      useNativeDriver: true,
    }).start();
  };

  const handleSetDurations = () => {
    Animated.timing(pickerTranslateY, {
      toValue: -height,
      duration: 500,
      useNativeDriver: true,
    }).start(() => {
      setShowPickers(false);
      setTotalTime(focusDuration);
      setElapsed(0);
      setIsFocusTime(true);
      setTimerRunning(true);
      setShowButton(false);
    });
  };

  useEffect(() => {
    if (timerRunning) {
      intervalRef.current = setInterval(() => {
        setElapsed(prev => {
          if (prev + 1 >= totalTime) {
            playSound();
            clearInterval(intervalRef.current);
            const isNowFocus = !isFocusTime;
            const newTotal = isNowFocus ? focusDuration : breakDuration;
            setIsFocusTime(isNowFocus);
            setTotalTime(newTotal);
            setElapsed(0);
            setTimerRunning(true);

            if (!isFocusTime) {
              setCompletedCycles(prev => prev + 1);
              setShowPickers(true);
              setShowButton(true);
              animatePickersIn();
            }

            return 0;
          }
          return prev + 1;
        });
      }, 1000);
      return () => clearInterval(intervalRef.current);
    }
  }, [timerRunning, totalTime, isFocusTime]);

  const playSound = async () => {
    if (sound) {
      await sound.replayAsync();
    }
  };

  const panResponder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onPanResponderMove: (_, gestureState) => {
        const percentage = Math.min(1, Math.max(0, gestureState.moveX / width));
        const newTime = Math.round((isFocusTime ? focusDuration : breakDuration) * percentage);
        setElapsed(newTime);
      },
    })
  ).current;

  const formattedTime = () => {
    const remaining = totalTime - elapsed;
    const mins = Math.floor(remaining / 60);
    const secs = remaining % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  // ⏱ Keep progress ratio when focusDuration changes during focus
  useEffect(() => {
    if (!timerRunning || !isFocusTime) return;
    setElapsed(prev => Math.floor((prev / totalTime) * focusDuration));
    setTotalTime(focusDuration);
  }, [focusDuration]);

  // ⏱ Keep progress ratio when breakDuration changes during break
  useEffect(() => {
    if (!timerRunning || isFocusTime) return;
    setElapsed(prev => Math.floor((prev / totalTime) * breakDuration));
    setTotalTime(breakDuration);
  }, [breakDuration]);

  return (
    <View style={styles.container}>
      {logoVisible && (
        <Animated.View style={[styles.logoScreen, { opacity: logoOpacity }]}>
          <Image
            source={require('./assets/logo.png')}
            style={styles.logo}
            resizeMode="contain"
          />
        </Animated.View>
      )}

      {showPickers && (
        <>
          <Animated.View style={[styles.pickerWrapper, { transform: [{ translateY: pickerTranslateY }] }]}>
            <View style={styles.pickerColumn}>
              <Text style={styles.label}>Focus Time</Text>
              <Picker
                selectedValue={String(focusDuration / 60)}
                onValueChange={value => setFocusDuration(Number(value) * 60)}
                style={styles.picker}
              >
                {[...Array(10)].map((_, i) => {
                  const val = (i + 3) * 5;
                  return <Picker.Item key={val} label={`${val} minutes`} value={String(val)} />;
                })}
              </Picker>
            </View>

            <View style={styles.pickerColumn}>
              <Text style={styles.label}>Break Time</Text>
              <Picker
                selectedValue={String(breakDuration / 60)}
                onValueChange={value => setBreakDuration(Number(value) * 60)}
                style={styles.picker}
              >
                {[...Array(10)].map((_, i) => {
                  const val = (i + 1) * 5;
                  return <Picker.Item key={val} label={`${val} minutes`} value={String(val)} />;
                })}
              </Picker>
            </View>
          </Animated.View>

          {showButton && (
            <View style={styles.buttonContainer}>
              <Button title="Set Durations" onPress={handleSetDurations} />
            </View>
          )}
        </>
      )}

      {!showPickers && (
        <View style={styles.progressContainer} {...panResponder.panHandlers}>
          <View style={styles.barContainer}>
            <View style={[styles.barFill, { width: `${(elapsed / totalTime) * 100}%` }]} />
            <View style={styles.overlay}>
              <Text style={styles.timerTitle}>{isFocusTime ? 'Focus Time' : 'Break Time'}</Text>
              <Text style={styles.timerText}>{formattedTime()}</Text>
            </View>
          </View>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'skyblue',
    justifyContent: 'center',
    alignItems: 'center',

  },
  logoScreen: {
    position: 'absolute',
    height: '100%',
    width: '100%',
    backgroundColor:'rgb(67, 184, 248)',
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 10,
  },
  logo: {
    width: 400,
    height: 400,
    borderRadius:10,
  },
  pickerWrapper: {
    width: '90%',
    flex: 1,
    alignItems: 'flex-end',
    flexDirection: 'row',
  },
  pickerColumn: {
    borderRadius: 12,
    padding: 10,
    width: '50%',
    elevation: 3,
    alignItems: 'center',
    height: 300,
  },
  picker: {
    height: 250,
    width: '100%',
    backgroundColor: 'skyblue',
    borderRadius:10,
    width:300,


  },
  label: {
    fontSize: 20,
    color:'white',
    fontWeight: '500',
    marginBottom: 8,
    width:200,
    textAlign: 'center',
    borderBottomColor:'white',
    borderBottomWidth:1,

  },
  buttonContainer: {
    height: 40,
    marginBottom:40,
    borderRadius:10,
    justifyContent: 'center',
    backgroundColor:'white'
  },
  progressContainer: {
    flex: 1,
    justifyContent: 'center',
    width: '100%',
  },
  barContainer: {
    height: '100%',
    width: '100%',
    backgroundColor: 'orange',
  },
  barFill: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    backgroundColor: 'skyblue',
  },
  overlay: {
    position: 'absolute',
    top: '40%',
    width: '100%',
    alignItems: 'center',
  },
  timerText: {
    fontSize: 48,
    fontWeight: 'bold',
    color: 'white',
  },
  timerTitle: {
    fontSize: 24,
    fontWeight: '600',
    color: 'white',
    marginBottom: 10,
  },
});