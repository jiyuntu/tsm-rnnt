local BATCH_SIZE = 32;
local FRAME_RATE = 1;
local ENCODER_HIDDEN_SIZE = 256;
local DECODER_HIDDEN_SIZE = 256;
local VGG = true;
local OUT_CHANNEL = 32;
local NUM_THREADS = 1;
local NUM_GPUS = 1;
local VOCAB_PATH = "runs/vocabulary/phoneme";
local TARGET_NAMESPACE = "target_tokens";

local BASE_ITERATOR = {
  "type": "bucket",
  "max_instances_in_memory": 128 * NUM_GPUS,
  "batch_size": BATCH_SIZE,
  "sorting_keys": [["source_features", "dimension_0"],
                   [TARGET_NAMESPACE, "num_tokens"]]
  #"maximum_samples_per_batch": ["dimension_0", 40000]
};

local BASE_READER = {
    "type": "kaldi-stt",
    "lazy": true,
    "shard_size": BATCH_SIZE,
    "input_stack_rate": FRAME_RATE,
    "model_stack_rate": 4,
    "lexicon_path": "/home/nlpmaster/lexicon.txt",
    "transcript_path": "/home/nlpmaster/Works/egs/pts/s5/data/all/text",
    "target_add_start_end_token": true,
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

{
  "random_seed": 13370,
  "numpy_seed": 1337,
  "pytorch_seed": 133,
  "dataset_reader": {
    "type": "multiprocess",
    "base_reader": BASE_READER,
    "num_workers": NUM_THREADS,
    "output_queue_size": 1024
  },
  "vocabulary": {
    "directory_path": "runs/vocabulary/word"
  },
  "train_data_path": "/home/nlpmaster/Works/egs/pts/s5/fbank/*_train.*.scp",
  "validation_data_path": "/home/nlpmaster/Works/egs/pts/s5/fbank/*_test.*.scp",
  "model": {
    "type": "seq2seq_mocha",
    "input_size": 80 * FRAME_RATE,
    "has_vgg": VGG,
    "vgg_out_channel": OUT_CHANNEL,
    "encoder": {
      "type": "awd-rnn",
      "input_size": 80 * (if VGG then OUT_CHANNEL / 4 else 1) * FRAME_RATE,
      "hidden_size": ENCODER_HIDDEN_SIZE,
      "num_layers": 4,
      "dropout": 0.25,
      "dropouth": 0.25,
      "dropouti": 0.25,
      "wdrop": 0.1,
      "stack_rates": [1, 1, 1, 1],
    },
    "max_decoding_steps": 30,
    "target_embedding_dim": DECODER_HIDDEN_SIZE,
    "beam_size": 5,
    "attention": {
      "type": "mocha",
      "chunk_size": 6,
      "enc_dim": ENCODER_HIDDEN_SIZE,
      "dec_dim": DECODER_HIDDEN_SIZE,
      "att_dim": DECODER_HIDDEN_SIZE
    },
    "target_namespace": "target_tokens",
    "initializer": [
      [".*linear.*weight", {"type": "xavier_uniform"}],
      [".*linear.*bias", {"type": "zero"}],
      [".*weight_ih.*", {"type": "xavier_uniform"}],
      [".*weight_hh.*", {"type": "orthogonal"}],
      [".*bias_ih.*", {"type": "zero"}],
      [".*bias_hh.*", {"type": "lstm_hidden_bias"}],
      ["_target_embedder.weight", {"type": "uniform", "a": -1, "b": 1}],
    ]
  },
  "iterator": {
    "type": "multiprocess",
    "base_iterator": BASE_ITERATOR,
    "num_workers": NUM_THREADS,
    "output_queue_size": 1024
  }, 
  "trainer": {
    "num_epochs": 300,
    "patience": 20,
    "grad_norm": 8.0,
    "cuda_device": 0,
    "validation_metric": "-WER",
    "num_serialized_models_to_keep": 2,
    "learning_rate_scheduler": {
      "type": "multi_step",
      "milestones": [8, 16, 24],
      "gamma": 0.1
    },
    "optimizer": {
      "type": "dense_sparse_adam",
      "lr": 0.0002,
      "eps": 1e-6
    }
  }
}
