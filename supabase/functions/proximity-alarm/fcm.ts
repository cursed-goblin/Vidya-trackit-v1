// Shared FCM v1 helpers for the proximity-alarm function.
export const FCM_ENDPOINT = (project: string) =>
  `https://fcm.googleapis.com/v1/projects/${project}/messages:send`;
