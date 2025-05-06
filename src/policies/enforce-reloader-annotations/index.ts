import { enforceAnnotations } from "../../lib/metadata/enforceAnnotations";

const annotations = {
  "reloader.stakater.com/auto": "true",
};

if (request.object) {
  request.object = enforceAnnotations(request, annotations);
  mutate(request.object);
}
