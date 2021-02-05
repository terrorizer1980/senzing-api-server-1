package com.senzing.api.server.mq;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import com.senzing.api.server.SzApiServer;

/**
 * A factory for converting messaging endpoint URLs into instances of
 * {@link SzMessagingEndpoint} instances.
 */
public class SzMessagingEndpointFactory {
  /**
   * The list of initiators to try.
   */
  private static final List<SzMessagingEndpoint.Initiator> INITIATORS;

  // initialize the list of initiators
  static {
    List<SzMessagingEndpoint.Initiator> list = new ArrayList<>(3);
    list.add(SqsEndpoint.INITIATOR);
    list.add(RabbitEndpoint.INITIATOR);
    list.add(KafkaEndpoint.INITIATOR);
    INITIATORS = Collections.unmodifiableList(list);
  }

  /**
   * Private default constructor.
   */
  private SzMessagingEndpointFactory() {
    // do nothing
  }

  /**
   * Creates the appropriate {@link SzMessagingEndpoint} from the specified URL.
   *
   * @param url The messaging endpoint URL.
   *
   * @param concurrency The concurrency of the {@link SzApiServer} to use for
   *                    creating pooled resources.
   *
   * @return The {@link SzMessagingEndpoint} for the specified URL.
   *
   * @throws IllegalArgumentException If the specified URL has an unrecognized
   *                                  format.
   */
  public static SzMessagingEndpoint createEndpoint(String url, int concurrency)
  {
    SzMessagingEndpoint endpoint = null;
    for (SzMessagingEndpoint.Initiator initiator: INITIATORS) {
      endpoint = initiator.establish(url, concurrency);
      if (endpoint != null) return endpoint;
    }
    throw new IllegalArgumentException(
        "Unrecognized messaging endpoint URL: " + url);
  }
}
