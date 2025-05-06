import {
  V1DaemonSet,
  V1Deployment,
  V1StatefulSet,
} from "@kubernetes/client-node";
import { enforceAnnotations } from "../../src/lib/metadata/enforceAnnotations";
import { V1AdmissionRequest } from "@jspolicy/types";

describe("enforceAnnotations", () => {
  test("should handle empty metadata", () => {
    // prepare
    const object: V1DaemonSet = {
      metadata: {},
    };
    const request: V1AdmissionRequest = {
      object: object,
    } as V1AdmissionRequest;
    const annotations = {
      "test.key": "value",
    };

    // test
    const response = enforceAnnotations(request, annotations) as V1DaemonSet;

    // validate
    expect(response).toBeDefined();
    expect(response.metadata?.annotations).toEqual({
      "test.key": "value",
    });
  });

  test("should handle empty annotations", () => {
    // prepare
    const object: V1Deployment = {
      metadata: {
        annotations: {},
      },
    };
    const request: V1AdmissionRequest = {
      object: object,
    } as V1AdmissionRequest;
    const annotations = {
      "test.key": "value",
    };

    // test
    const response = enforceAnnotations(request, annotations) as V1Deployment;

    // validate
    expect(response).toBeDefined();
    expect(response.metadata?.annotations).toEqual({
      "test.key": "value",
    });
  });

  test("should retain existing annotations", () => {
    // prepare
    const object: V1StatefulSet = {
      metadata: {
        annotations: {
          "example.com/key": "test",
        },
      },
    };
    const request: V1AdmissionRequest = {
      object: object,
    } as V1AdmissionRequest;
    const annotations = {
      "test.key": "value",
    };

    // test
    const response = enforceAnnotations(request, annotations) as V1StatefulSet;

    // validate
    expect(response).toBeDefined();
    expect(response.metadata?.annotations).toEqual({
      "test.key": "value",
      "example.com/key": "test",
    });
  });
});
