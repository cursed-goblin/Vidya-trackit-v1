// FCM v1 endpoint helper for the proximity-alarm function.
const FCM_HOST = "https://fcm.googleapis.com";

export const FCM_ENDPOINT = (project: string) =>
  FCM_HOST + "/v1/projects/" + project + "/messages:send";
