import { Stack } from 'expo-router';

export default function RootLayout() {
  return (
    <Stack>
      <Stack.Screen name="index" options={{ title: 'Training Triangle' }} />
      <Stack.Screen name="login" options={{ title: 'Sign In' }} />
    </Stack>
  );
}
