import { V1AdmissionRequest } from "@jspolicy/types";
import { V1ObjectMeta } from "@kubernetes/client-node";

export function enforceAnnotations(
    request: V1AdmissionRequest,
    annotations: { [key: string]: string },
): object {
    const obj = request.object as { metadata?: V1ObjectMeta };

    if (obj) {
        if (!obj.metadata) {
            obj.metadata = {};
        }

        if (!obj.metadata.annotations) {
            obj.metadata.annotations = {};
        }

        for (const key in annotations) {
            if (Object.prototype.hasOwnProperty.call(annotations, key)) {
                obj.metadata.annotations[key] = annotations[key];
            }
        }
    }
    request.object = obj;

    return request.object || {};
}
