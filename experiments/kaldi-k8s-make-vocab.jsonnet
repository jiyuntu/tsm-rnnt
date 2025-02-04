local BATCH_SIZE = 32;
local FRAME_RATE = 3;
local NUM_THREADS = 1;
local NUM_GPUS = 1;
local VOCAB_PATH = std.extVar('VOCAB_PATH') + "/vocabulary";
local TARGET_NAMESPACE = "target_tokens";

local BASE_READER = {
    "type": "kaldi-stt",
    "lazy": true,
    "shard_size": BATCH_SIZE,
    "input_stack_rate": FRAME_RATE,
    "model_stack_rate": 2,
    "lexicon_path": std.extVar('DATA_HOME') + "/ASR-Training/resource-en/lexicon.txt",
    "transcript_path": std.extVar('DATA_HOME') + "/data/*/data/mfcc/*/seg.scp",
    "target_tokenizer": {
      "type": "word",
      "word_splitter": {
        "type": "just_spaces"
      }
    },
    "target_token_indexers": {
      "tokens": {
        "type": "single_id",        
        "namespace": TARGET_NAMESPACE
      }
    }
};
local BASE_ITERATOR = {
  "type": "bucket",
  "max_instances_in_memory": 64 * NUM_GPUS,
  "batch_size": BATCH_SIZE,
  "sorting_keys": [["source_features", "dimension_0"]],
  "maximum_samples_per_batch": ["dimension_0", 6400]
};

{
  "dataset_reader": {
    "type": "multiprocess",
    "base_reader": BASE_READER,
    "num_workers": NUM_THREADS,
    "output_queue_size": 1024
  },
  "train_data_path": std.extVar('DATA_HOME') + "/data/*/data/mfcc/train/raw_mfcc_train.*.scp",
  "validation_data_path": std.extVar('DATA_HOME') + "/data/PTS_clear/data/mfcc/test/raw_mfcc_test.*.scp",
  "test_data_path": std.extVar('DATA_HOME') + "/data/Youtube2/data/mfcc/test/raw_mfcc_test.*.scp",
  "model": {
    "type": "ctc",
    "loss_type": "ctc",
    "encoder": {
      "type": "awd-rnn",
      "input_size": 83 * FRAME_RATE,
      "hidden_size": 512,
      "num_layers": 4,
      "dropout": 0.5,
      "dropouth": 0.5,
      "dropouti": 0.5,
      "wdrop": 0.1,
      "stack_rates": [1, 1, 2, 1],
    },
    "vocab_path": VOCAB_PATH,
    "target_namespace": TARGET_NAMESPACE,
  },
  "iterator": {
    "type": "multiprocess",
    "base_iterator": BASE_ITERATOR,
    "num_workers": NUM_THREADS,
    "output_queue_size": 1024
  },
  "trainer": {
    "num_epochs": 300,
    "patience": 10,
    "grad_clipping": 5.0,
    "cuda_device": 0,
    "validation_metric": "-WER",
    "num_serialized_models_to_keep": 1,
    "learning_rate_scheduler": {
      "type": "reduce_on_plateau",
      "factor": 0.8,
      "mode": "min",
      "patience": 5
    },
    "optimizer": {
      "type": "dense_sparse_adam",
      "lr": 0.0003
    }
  }
}
